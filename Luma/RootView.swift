import SwiftUI

struct RootView: View {
    @Bindable var store: LumaStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch store.session {
                case .ready:
                    TabView(selection: $store.tab) {
                        Tab(value: EditorTab.message) {
                            MessageView(store: store)
                        } label: { Label { Text("Message") } icon: { Image("Figma65d73") } }
                        Tab(value: EditorTab.icons) {
                            IconsView(store: store)
                        } label: { Label { Text("Icônes") } icon: { Image("Figma69917") } }
                        Tab(value: EditorTab.tools) {
                            ToolsView(store: store)
                        } label: { Label("Activités", systemImage: "clock") }
                        Tab(value: EditorTab.settings) {
                            SettingsView(store: store)
                        } label: { Label { Text("Panneau") } icon: { Image("Figmad1a93") } }
                    }
                default:
                    ConnectionView(store: store)
                }
            }
        }.background(Color("bg")).foregroundStyle(Color("text"))
            .onChange(of: scenePhase) { if scenePhase == .background { store.stopVisualizer(); store.stopOBD(); store.stopTranscription() } }
            .sheet(item: $store.sheet) { sheet in LumaSheetView(store: store, sheet: sheet) }
            .alert("Luma", isPresented: Binding(
                get: { store.storageError != nil },
                set: { if !$0 { store.storageError = nil } }
            )) { Button("Fermer") { store.storageError = nil } }
            message: { Text(store.storageError ?? "") }
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 3) {
                    Text("luma").font(.title.weight(.heavy)).tracking(-0.7)
                    FigmaIcon(asset: "3b498")
                }.accessibilityElement(children: .ignore).accessibilityLabel("Luma")
                Spacer()
                Button {
                    if store.isReady { store.tab = .settings } else { store.sheet = .help }
                } label: {
                    HStack(spacing: 8) {
                        FigmaIcon(asset: store.isReady ? "a7628" : "a7555")
                        Text(store.isReady ? store.panel.name : "Hors ligne").font(.caption2)
                        FigmaIcon(asset: "47026")
                    }.foregroundStyle(Color("muted"))
                        .padding(.horizontal, 12).frame(minHeight: 36)
                        .lumaCard(radius: 20)
                }.buttonStyle(.plain).frame(minHeight: 44)
            }

        }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 14)
    }
}

struct EditorPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LumaTitle(title: title, subtitle: subtitle)
                content
            }.padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).background(Color("bg"))
    }
}

struct EditorActions: View {
    @Bindable var store: LumaStore
    var settings = false
    var body: some View {
        VStack(spacing: 4) {
            Button(settings ? "✓  Appliquer les réglages" : "→  Afficher sur le panneau") {
                if settings { store.apply() } else { store.display() }
            }.buttonStyle(PrimaryButton())
                .disabled(!settings && store.tab == .message && PixelRenderer.validationError(store.draft.message) != nil)
                .accessibilityIdentifier(settings ? "apply" : "send")
            Button(settings ? "Déconnecter" : "Effacer le panneau") {
                store.sheet = settings ? .disconnect : .clear
            }.buttonStyle(QuietButton())
        }.padding(.horizontal, 24).padding(.top, 8)
            .frame(maxWidth: 560).frame(maxWidth: .infinity).background(Color("bg"))
    }
}
