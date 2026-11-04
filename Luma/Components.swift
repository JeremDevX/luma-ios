import SwiftUI

struct FigmaIcon: View {
    let asset: String
    var body: some View { Image("Figma" + asset).renderingMode(.original) }
}

struct LumaTitle: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title.weight(.heavy)).tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.footnote).foregroundStyle(Color("muted"))
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.footnote.weight(.heavy))
            .frame(maxWidth: .infinity).frame(minHeight: 52)
            .foregroundStyle(Color("ink"))
            .background(Color("accent"), in: RoundedRectangle(cornerRadius: 16))
            .opacity(!isEnabled ? 0.4 : configuration.isPressed ? 0.75 : 1)
    }
}

struct QuietButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.footnote.weight(.bold))
            .frame(maxWidth: .infinity).frame(minHeight: 44)
            .foregroundStyle(Color("muted"))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    func lumaCard(fill: String = "surface", stroke: String = "line", radius: CGFloat = 20) -> some View {
        background(Color(fill), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(stroke), lineWidth: 1))
    }
}

struct PanelIdentity: View {
    let panel: Panel
    var body: some View {
        HStack(spacing: 12) {
            FigmaIcon(asset: "ef422")
            VStack(alignment: .leading, spacing: 4) {
                Text(panel.name).font(.callout.bold())
                Text(panel.specification).font(.caption2).foregroundStyle(Color("muted"))
            }
            Spacer(minLength: 0)
        }
    }
}

struct ColorPalette: View {
    @Binding var selection: LEDColor
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Couleur").font(.footnote.bold())
                Spacer()
                Text(selection.rawValue).font(.caption2).foregroundStyle(Color("muted"))
            }
            HStack(spacing: 0) {
                ForEach(LEDColor.allCases) { color in
                    if color != .citron { Spacer(minLength: 0) }
                    Button { selection = color } label: {
                        FigmaIcon(asset: color.swatch)
                            .overlay {
                                if selection == color {
                                    Circle().stroke(Color("text"), lineWidth: 1)
                                    Image(systemName: "checkmark").font(.caption.bold())
                                        .foregroundStyle(Color("ink"))
                                }
                            }.frame(width: 44, height: 44)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(color.rawValue)
                        .accessibilityAddTraits(selection == color ? .isSelected : [])
                }
            }
        }
    }
}

struct PreviewPanel: View {
    let draft: Draft
    let panel: Panel
    var icon = false
    var drawing: [Bool]? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var paused = false
    @State private var offset = 0
    @State private var visibleColumns = 32
    private var moving: Bool {
        !icon && draft.isOn && PixelRenderer.shouldScroll(draft.message, panel: panel, mode: draft.scrollMode)
    }

    private var showingPages: Bool { !icon && draft.isOn && draft.scrollMode == .appearance }

    var body: some View {
        VStack(spacing: drawing == nil ? 12 : 4) {
            HStack {
                Text("APERÇU")
                Spacer()
                Text("\(panel.columns) × \(panel.rows)")
            }.font(.caption2.bold()).foregroundStyle(Color("muted"))
            PixelGrid(grid: PixelRenderer.grid(draft: draft, panel: panel, icon: icon,
                                               offset: reduceMotion ? (showingPages ? 0 : moving ? panel.columns : offset) : offset, drawing: drawing),
                      color: Color(draft.color.asset),
                      brightness: draft.brightness,
                      visibleColumns: showingPages && !reduceMotion ? visibleColumns : nil)
                .aspectRatio(CGFloat(panel.columns) / CGFloat(panel.rows), contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(drawing == nil ? 8 : 4).frame(maxWidth: .infinity)
                .background(Color("black"), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(drawing != nil ? "Dessin personnalisé" : icon ? draft.pictogram.rawValue : draft.message)
                .accessibilityValue(draft.isOn ? "Aperçu allumé" : "Aperçu éteint")
            if drawing == nil {
            HStack {
                Text(draft.scrollMode.rawValue).font(.caption2)
                Spacer()
                Button { paused.toggle() } label: {
                    Group {
                        if paused { Image(systemName: "play.fill").font(.caption2) }
                        else { FigmaIcon(asset: "16b09") }
                    }.frame(width: 44, height: 28)
                }.buttonStyle(.plain)
                    .accessibilityLabel(paused ? "Reprendre l’aperçu" : "Mettre l’aperçu en pause")
            }.foregroundStyle(Color("muted"))
            }
        }.padding(.horizontal, 16).padding(.vertical, drawing == nil ? 16 : 8)
            .lumaCard(fill: drawing == nil ? "panel" : "surface",
                      stroke: drawing == nil ? "panelLine" : "line", radius: 24)
            .task(id: AnimationKey(draft: draft, icon: icon, panel: panel, paused: paused,
                                  reduceMotion: reduceMotion, active: scenePhase == .active)) {
                guard (moving || showingPages), !paused, !reduceMotion, scenePhase == .active else { return }
                if showingPages {
                    while !Task.isCancelled {
                        for step in 0..<8 {
                            visibleColumns = step * 4
                            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                        }
                        visibleColumns = 32
                        do { try await Task.sleep(for: .seconds(draft.speed.appearanceInterval - 1.6)) } catch { return }
                        for step in (1...8).reversed() {
                            visibleColumns = step * 4
                            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                        }
                        visibleColumns = 0
                        offset += 1
                    }
                } else {
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(draft.speed.interval)) } catch { return }
                        offset += 1
                    }
                }
            }
            .onChange(of: draft.message) { offset = 0 }
            .onChange(of: draft.scrollMode) { offset = 0; visibleColumns = 32 }
            .onChange(of: panel) { offset = 0 }
    }

    private struct AnimationKey: Equatable {
        let draft: Draft
        let icon: Bool
        let panel: Panel
        let paused: Bool
        let reduceMotion: Bool
        let active: Bool
    }
}

struct PixelGrid: View {
    let grid: [[Bool]]
    let color: Color
    var brightness = 100.0
    var visibleColumns: Int? = nil
    var body: some View {
        Canvas { context, size in
            guard let columns = grid.first?.count, columns > 0, !grid.isEmpty else { return }
            let step = min(size.width / CGFloat(columns), size.height / CGFloat(grid.count))
            for y in grid.indices {
                for x in grid[y].indices {
                    let rect = CGRect(x: CGFloat(x) * step + step * 0.19,
                                      y: CGFloat(y) * step + step * 0.19,
                                      width: step * 0.62, height: step * 0.62)
                    let lit = grid[y][x] && brightness > 0 && x < (visibleColumns ?? columns)
                    context.fill(Path(roundedRect: rect, cornerRadius: step * 0.06),
                                 with: .color(lit ? color.opacity(0.4 + brightness * 0.006) : Color("pixelOff")))
                }
            }
        }.accessibilityHidden(true)
    }
}
