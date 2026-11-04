import SwiftUI

struct SettingsView: View {
    @Bindable var store: LumaStore
    var body: some View {
        EditorPage(title: "Réglages", subtitle: "Ajuste ton panneau.") {
            PanelIdentity(panel: store.panel).padding(16).lumaCard()
            VStack(spacing: 10) {
                HStack {
                    Text("Luminosité").font(.footnote.bold())
                    Spacer()
                    Text("\(Int(store.draft.brightness)) %")
                        .font(.footnote.bold()).foregroundStyle(Color("accent"))
                }
                Slider(value: $store.draft.brightness, in: 0...100, step: 1)
                    .accessibilityLabel("Luminosité")
                    .accessibilityValue("\(Int(store.draft.brightness)) pour cent")
                HStack {
                    Text("Discrète")
                    Spacer()
                    Text("Intense")
                }.font(.caption2).foregroundStyle(Color("muted"))
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Mode d’affichage").font(.footnote.bold())
                Picker("Mode d’affichage", selection: $store.draft.scrollMode) {
                    ForEach(ScrollMode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
                Text("Auto : défile au-delà de \(store.panel.capacity) caractères. Apparition : un mot par écran, découpé après 5 caractères.")
                    .font(.caption2).foregroundStyle(Color("muted"))
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Vitesse").font(.footnote.bold())
                    Spacer()
                    Text(store.draft.speed.rawValue).font(.footnote.bold()).foregroundStyle(Color("accent"))
                }
                Picker("Vitesse", selection: $store.draft.speed) {
                    ForEach(Speed.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }
            Toggle("Panneau allumé", isOn: $store.draft.isOn).font(.footnote.bold())
            Text("Le MAX7219 est monochrome : la couleur choisie concerne uniquement l’aperçu.").font(.footnote).foregroundStyle(Color("muted"))
        }.safeAreaInset(edge: .bottom, spacing: 0) { EditorActions(store: store, settings: true) }
    }
}
