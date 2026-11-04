import SwiftUI

struct OBDControlsView: View {
    @Bindable var store: LumaStore
    @AppStorage("luma.obd.simulator.host") private var host = ""
    @AppStorage("luma.obd.maximum") private var maximum = 6000

    private var columns: Int {
        min(32, max(0, (store.obdRPM ?? 0) * 32 / max(1, maximum)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connecte le simulateur lancé sur ton Mac. Les deux appareils doivent être sur le même Wi-Fi.")
                .font(.caption).foregroundStyle(Color("muted"))
            TextField("Adresse IP du Mac", text: $host)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(10).lumaCard(radius: 10).disabled(store.obdActive)
                .accessibilityIdentifier("obd-host")
            Stepper("Maximum : \(maximum) tr/min", value: $maximum, in: 1000...12000, step: 500)
                .onChange(of: maximum) { store.setOBDMaximum(maximum) }
            HStack {
                Text(store.obdRPM.map { "\($0) tr/min" } ?? "— tr/min").font(.headline)
                Spacer()
                Text(store.obdStatus).font(.caption).foregroundStyle(Color("muted"))
            }
            PixelGrid(grid: (0..<8).map { _ in (0..<32).map { $0 < columns } }, color: Color("accent"))
                .aspectRatio(4, contentMode: .fit).padding(8).background(.black, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Compte-tours : \(store.obdRPM.map(String.init) ?? "aucune donnée") tours par minute")
            if store.obdActive {
                Button("Arrêter le compte-tours") { store.stopOBD() }.buttonStyle(PrimaryButton())
            } else {
                Button("Connecter le simulateur") { store.startOBD(host: host, maximum: maximum) }
                    .buttonStyle(PrimaryButton()).disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("Données simulées uniquement. Ne pas utiliser cet affichage comme indicateur de conduite.")
                .font(.caption).foregroundStyle(Color("muted"))
        }
    }
}
