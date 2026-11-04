import SwiftUI

struct DrawingView: View {
    @Bindable var store: LumaStore
    @State private var stroke = DrawingStroke()
    @State private var square = 0

    var body: some View {
        EditorPage(title: "Ton dessin", subtitle: "Touche, puis glisse pour ajouter ou effacer les pixels.") {
            PreviewPanel(draft: store.draft, panel: store.panel, icon: true, drawing: store.drawing)
            HStack {
                Text("Carré \(square + 1) sur 4").font(.footnote.bold())
                Spacer()
                Text(stroke.mode.map { $0 ? "Ajout" : "Effacement" } ?? "Glisse pour dessiner")
                    .font(.caption).foregroundStyle(Color("muted"))
            }
            Picker("Carré à dessiner", selection: $square) {
                ForEach(0..<4) { Text("\($0 + 1)").tag($0) }
            }.pickerStyle(.segmented)
                .onChange(of: square) { stroke = DrawingStroke() }
            GeometryReader { geometry in
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 8), spacing: 3) {
                    ForEach(0..<64) { localIndex in
                        let index = (localIndex / 8) * 32 + square * 8 + localIndex % 8
                        Button { store.drawing[index].toggle() } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(store.drawing[index] ? store.draft.color.asset : "raised"))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color("line")))
                                .aspectRatio(1, contentMode: .fit)
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("pixel-\(index)")
                            .accessibilityLabel("Ligne \(index / 32 + 1), colonne \(index % 32 + 1)")
                            .accessibilityValue(store.drawing[index] ? "Allumé" : "Éteint")
                    }
                }.contentShape(Rectangle())
                    .highPriorityGesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            var pixels = store.drawing
                            stroke.paint(at: value.location, size: geometry.size, pixels: &pixels, columnOffset: square * 8)
                            if pixels != store.drawing { store.drawing = pixels }
                        }
                        .onEnded { _ in stroke = DrawingStroke() })
            }.aspectRatio(1, contentMode: .fit).padding(12).lumaCard(radius: 16)
            ColorPalette(selection: $store.draft.color)
            if store.drawingFavorites.count == 20 && !store.isDrawingFavorite {
                Text("20 dessins favoris maximum. Retire un favori pour en ajouter un nouveau.")
                    .font(.caption).foregroundStyle(Color("muted"))
            }
        }.onDisappear { stroke = DrawingStroke() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 4) {
                    Button("Valider le dessin") { store.validateDrawing() }
                        .buttonStyle(PrimaryButton()).disabled(!store.drawing.contains(true))
                        .accessibilityIdentifier("validate-drawing")
                    HStack {
                        Button { store.toggleDrawingFavorite() } label: {
                            Label(store.isDrawingFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                                  systemImage: store.isDrawingFavorite ? "star.fill" : "star")
                        }.buttonStyle(QuietButton())
                            .disabled(!store.drawing.contains(true) ||
                                      (!store.isDrawingFavorite && store.drawingFavorites.count >= 20))
                            .accessibilityIdentifier("favorite-drawing")
                        Button("Retour aux icônes") { store.isDrawing = false }.buttonStyle(QuietButton())
                    }
                    Button("Effacer le dessin") { store.sheet = .clearDrawing }.buttonStyle(QuietButton())
                }.padding(.horizontal, 24).padding(.top, 8)
                    .frame(maxWidth: 560).frame(maxWidth: .infinity).background(Color("bg"))
            }
    }
}

struct DrawingFavoritesView: View {
    @Bindable var store: LumaStore
    var body: some View {
        if !store.drawingFavorites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dessins favoris").font(.footnote.bold())
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(store.drawingFavorites.enumerated()), id: \.element.id) { index, favorite in
                            Button { store.selectDrawing(favorite) } label: {
                                VStack(spacing: 8) {
                                    PixelGrid(grid: (0..<8).map { row in
                                        Array(favorite.pixels[row * 32..<row * 32 + 32])
                                    }, color: Color(favorite.color.asset)).frame(width: 96, height: 24)
                                    Text("Dessin \(index + 1)").font(.caption)
                                }.padding(12).frame(minWidth: 92)
                                    .lumaCard(stroke: store.selectedDrawing?.id == favorite.id ? "accent" : "line")
                            }.buttonStyle(.plain)
                                .accessibilityLabel("Dessin favori \(index + 1)")
                                .accessibilityAddTraits(store.selectedDrawing?.id == favorite.id ? .isSelected : [])
                                .contextMenu {
                                    Button("Retirer des favoris", systemImage: "star.slash") {
                                        store.drawingFavorites.removeAll { $0.id == favorite.id }
                                    }
                                }
                        }
                    }.padding(1)
                }
            }
        }
    }
}

struct DrawingStroke {
    private(set) var mode: Bool?
    private var previous: CGPoint?

    mutating func paint(at point: CGPoint, size: CGSize, pixels: inout [Bool], columnOffset: Int = 0) {
        guard pixels.count == 256, (0...24).contains(columnOffset), size.width > 0, size.height > 0,
              point.x >= 0, point.y >= 0, point.x < size.width, point.y < size.height else {
            previous = nil
            return
        }
        let index = Int(point.y / size.height * 8) * 32 + columnOffset + Int(point.x / size.width * 8)
        if mode == nil { mode = !pixels[index] }
        guard let mode else { return }
        let start = previous ?? point
        let distance = max(abs(point.x - start.x) / size.width, abs(point.y - start.y) / size.height)
        let steps = max(1, Int(ceil(distance * 32)))
        for step in 0...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let x = start.x + (point.x - start.x) * fraction
            let y = start.y + (point.y - start.y) * fraction
            let column = min(7, max(0, Int(x / size.width * 8)))
            let row = min(7, max(0, Int(y / size.height * 8)))
            pixels[row * 32 + columnOffset + column] = mode
        }
        previous = point
    }
}
