import SwiftUI

struct LumaSheetView: View {
    @Bindable var store: LumaStore
    let sheet: LumaSheet
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FigmaIcon(asset: (sheet == .clear || sheet == .clearDrawing) ? "20f26" : "7f435")
                LumaTitle(title: title, subtitle: copy)
                if sheet == .sent, let draft = store.displayedDraft {
                    PreviewPanel(draft: draft, panel: store.panel, icon: store.displayedIcon, drawing: store.displayedDrawing)
                }
                switch sheet {
                case .clear:
                    Button("Effacer le panneau") { store.clear() }.buttonStyle(PrimaryButton())
                    Button("Annuler") { dismiss() }.buttonStyle(QuietButton())
                case .clearDrawing:
                    Button("Effacer le dessin") { store.clearDrawing() }.buttonStyle(PrimaryButton())
                        .accessibilityIdentifier("confirm-clear-drawing")
                    Button("Annuler") { dismiss() }.buttonStyle(QuietButton())
                case .disconnect:
                    Button("Déconnecter") { store.disconnect() }.buttonStyle(PrimaryButton())
                        .accessibilityIdentifier("confirm-disconnect")
                    Button("Annuler") { dismiss() }.buttonStyle(QuietButton())
                case .help:
                    Text("Allume ton ESP32 et active le Bluetooth.")
                        .font(.footnote).foregroundStyle(Color("muted"))
                    Button("Relancer la recherche") {
                        store.session = .selection; dismiss()
                    }.buttonStyle(PrimaryButton())
                    Button("Fermer") { dismiss() }.buttonStyle(QuietButton())
                case .sent, .applied, .feature:
                    Button("OK") { dismiss() }.buttonStyle(PrimaryButton())
                }
            }.padding(24).padding(.top, 12)
        }.foregroundStyle(Color("text"))
            .presentationBackground(Color("surface"))
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
            .presentationDetents(sheet == .sent || sheet == .help ? [.large] : [.medium, .large])
    }

    private var title: String {
        switch sheet {
        case .clearDrawing: "Effacer le dessin ?"
        case .clear: "Effacer le panneau ?"
        case .disconnect: "Déconnecter le panneau ?"
        case .help: "Panneau introuvable ?"
        case .sent: "Commande transmise"
        case .applied: "Réglages appliqués"
        case .feature: "Commande transmise"
        }
    }

    private var copy: String {
        switch sheet {
        case .clearDrawing: "La grille sera vidée."
        case .clear: "Le panneau sera effacé. Ton message et tes favoris sont gardés."
        case .disconnect: "Ton contenu reste sur le panneau. Tes réglages sont gardés."
        case .help: "Vérifie que le programme Luma est installé sur l’ESP32 et que le panneau est alimenté."
        case .sent: "La commande Bluetooth a été transmise. Vérifie le résultat sur le panneau."
        case .applied: "La commande Bluetooth a été transmise."
        case .feature: "Vérifie le résultat sur le panneau."
        }
    }
}
