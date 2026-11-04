import SwiftUI

struct MessageView: View {
    @Bindable var store: LumaStore
    @FocusState private var editing: Bool
    private var validation: String? { PixelRenderer.validationError(store.draft.message) }
    private var isFavorite: Bool {
        store.draft.favorites.contains(PixelRenderer.normalize(store.draft.message))
    }

    private var appearanceHint: String {
        let text = PixelRenderer.normalize(store.draft.message)
        let current = text.last == " " ? 0 : text.split(separator: " ").last?.count ?? 0
        let pages = PixelRenderer.appearancePages(text).count
        return "Mot actuel : \(current)/5 caractères · \(pages) écran(s). Les mots plus longs sont découpés."
    }

    var body: some View {
        EditorPage(title: "Ton message", subtitle: "Écris, puis affiche.") {
            PreviewPanel(draft: store.draft, panel: store.panel)
            Picker("Mode d’affichage", selection: $store.draft.scrollMode) {
                ForEach(ScrollMode.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.menu)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ton message").font(.footnote.bold())
                    Spacer()
                    Text("\(PixelRenderer.normalize(store.draft.message).count)/60")
                        .font(.caption2).foregroundStyle(Color("muted"))
                }
                HStack {
                    TextField("Ton message", text: $store.draft.message, axis: .vertical)
                        .font(.callout.bold()).lineLimit(1...3)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .focused($editing).submitLabel(.done)
                        .accessibilityIdentifier("message-input")
                    Button { store.toggleFavorite() } label: {
                        if isFavorite {
                            Image(systemName: "star.fill").foregroundStyle(Color("accent"))
                        } else { FigmaIcon(asset: "51477") }
                    }.buttonStyle(.plain).frame(width: 44, height: 44)
                        .disabled(validation != nil || (!isFavorite && store.draft.favorites.count >= 20))
                        .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
                }.padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 4)
                    .lumaCard(radius: 12)
                Text(validation ?? (store.draft.scrollMode == .appearance ? appearanceHint :
                    "Auto : défile au-delà de \(store.panel.capacity) caractères."))
                    .font(.caption2).foregroundStyle(Color(validation == nil ? "muted" : "error"))
            }
            ColorPalette(selection: $store.draft.color)
            VStack(alignment: .leading, spacing: 10) {
                Text("Favoris").font(.footnote.bold())
                if store.draft.favorites.isEmpty {
                    Text("Touche l’étoile pour garder tes mots préférés.")
                        .font(.caption).foregroundStyle(Color("muted"))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.draft.favorites, id: \.self) { message in
                            Button { store.draft.message = message; editing = false } label: {
                                Text(message).font(.caption2).padding(.horizontal, 16)
                                    .frame(minWidth: 90, minHeight: 44)
                                    .foregroundStyle(Color(store.draft.message == message ? "accent" : "muted"))
                                    .lumaCard(fill: store.draft.message == message ? "raised" : "surface", radius: 12)
                            }.buttonStyle(.plain)
                        }
                    }.padding(1)
                }
                if store.draft.favorites.count == 20 {
                    Text("20 favoris maximum. Retire-en un avec l’étoile pour en ajouter un autre.")
                        .font(.caption2).foregroundStyle(Color("muted"))
                }
            }
        }.safeAreaInset(edge: .bottom, spacing: 0) { EditorActions(store: store) }
            .onChange(of: store.sheet) { _, sheet in if sheet != nil { editing = false } }
    }
}

struct IconsView: View {
    @Bindable var store: LumaStore
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        if store.isDrawing {
            DrawingView(store: store)
        } else {
            EditorPage(title: "Icônes", subtitle: "Choisis une icône.") {
                Button("＋ Créer un dessin") { store.isDrawing = true }
                    .buttonStyle(QuietButton()).lumaCard(fill: "raised", radius: 16)
                PreviewPanel(draft: store.draft, panel: store.panel, icon: true, drawing: store.selectedDrawing?.pixels)
                Text("Choisir une icône").font(.footnote.bold())
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                        count: typeSize.isAccessibilitySize ? 2 : 3), spacing: 12) {
                    ForEach(Pictogram.allCases) { icon in
                        Button { store.selectedDrawing = nil; store.isDrawing = false; store.draft.pictogram = icon } label: {
                            VStack(spacing: 10) {
                                FigmaIcon(asset: icon.asset).frame(height: 48)
                                Text(icon.rawValue).font(.caption2)
                            }.frame(maxWidth: .infinity).frame(minHeight: 102)
                                .foregroundStyle(Color(store.selectedDrawing == nil && store.draft.pictogram == icon ? "text" : "muted"))
                                .lumaCard(fill: store.selectedDrawing == nil && store.draft.pictogram == icon ? "raised" : "surface",
                                          stroke: store.selectedDrawing == nil && store.draft.pictogram == icon ? "accent" : "line")
                        }.buttonStyle(.plain)
                            .accessibilityLabel(icon.rawValue)
                            .accessibilityAddTraits(store.selectedDrawing == nil && store.draft.pictogram == icon ? .isSelected : [])
                    }
                }
                DrawingFavoritesView(store: store)
            Text("Icônes en 8 × 8 pixels.")
                    .font(.caption2).foregroundStyle(Color("muted"))
                ColorPalette(selection: $store.draft.color)
            }.safeAreaInset(edge: .bottom, spacing: 0) { EditorActions(store: store) }
        }
    }
}
