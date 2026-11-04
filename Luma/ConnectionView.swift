@preconcurrency import CoreBluetooth
import SwiftUI

struct ConnectionView: View {
    @Bindable var store: LumaStore
    var body: some View {
        switch store.session {
        case .pairing(let panel):
            EditorPage(title: "Connexion…",
                       subtitle: "Recherche du panneau Bluetooth.") {
                FigmaIcon(asset: "dbcc8").frame(maxWidth: .infinity).frame(height: 280)
                HStack {
                    Text(panel.name).font(.callout.bold()).foregroundStyle(Color("accent"))
                    Spacer()
                    ProgressView().accessibilityLabel("Recherche Bluetooth")
                }
                Button("Annuler") { store.disconnect() }.buttonStyle(QuietButton())
            }
        case .offline(let panel):
            EditorPage(title: "Connexion perdue",
                       subtitle: "La connexion Bluetooth a été interrompue. Ton message est gardé.") {
                VStack(alignment: .leading, spacing: 20) {
                    FigmaIcon(asset: "ada68")
                    Text("Message sauvegardé").font(.callout.bold())
                    Text("Reconnecte-toi pour continuer.")
                        .font(.footnote).foregroundStyle(Color("muted"))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).lumaCard()
            }.safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button("↻  Reconnecter") { store.connect(panel) }.buttonStyle(PrimaryButton())
                    Button("Revenir à l’accueil") { store.disconnect() }.buttonStyle(QuietButton())
                }.padding(.horizontal, 24).background(Color("bg"))
            }
        default:
            EditorPage(title: "Connecte ton panneau",
                       subtitle: "Allume-le et active le Bluetooth.") {
                PreviewPanel(draft: Draft(), panel: .rgb)
                Text("Sans compte · Bluetooth")
                    .font(.caption2).foregroundStyle(Color("muted"))
                Button("Connecter") { store.connect(.rgb) }
                    .buttonStyle(PrimaryButton()).accessibilityIdentifier("connect-rgb")
            }.safeAreaInset(edge: .bottom) {
                Button("Mon panneau n’apparaît pas") { store.sheet = .help }
                    .buttonStyle(QuietButton()).padding(.horizontal, 24).background(Color("bg"))
            }
        }
    }
}


@MainActor final class LumaBluetooth: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    private let service = CBUUID(string: "7A2F0007-CB86-4B6D-8F78-38D24B9E1940")
    private let command = CBUUID(string: "7A2F0002-CB86-4B6D-8F78-38D24B9E1940")
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var pending: [Data] = []
    private var completion: ((Bool) -> Void)?
    private var queue: [([Data], (Bool) -> Void)] = []
    var onReady: (() -> Void)?
    var onError: ((String) -> Void)?

    func connect() {
        if let central { if central.state == .poweredOn { scan() } }
        else { central = CBCentralManager(delegate: self, queue: .main) }
    }
    func stop() {
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        peripheral = nil; characteristic = nil
        finish(false)
    }
    private func scan() { central?.scanForPeripherals(withServices: [service]) }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { scan() }
        else if central.state != .unknown && central.state != .resetting { onError?("Bluetooth indisponible ou non autorisé.") }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan(); self.peripheral = peripheral; peripheral.delegate = self
        central.connect(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { peripheral.discoverServices([service]) }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { onError?("Connexion impossible.") }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        characteristic = nil; finish(false); onError?("Connexion Bluetooth interrompue.")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let found = peripheral.services?.first(where: { $0.uuid == service }) else { onError?("Service Luma introuvable."); return }
        peripheral.discoverCharacteristics([command], for: found)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let found = service.characteristics?.first(where: { $0.uuid == command && $0.properties.contains(.write) }) else { onError?("Commande Luma introuvable."); return }
        characteristic = found; onReady?()
    }
    func send(_ packets: [Data], completion: @escaping (Bool) -> Void) {
        queue.append((packets, completion))
        startNext()
    }
    private func startNext() {
        guard completion == nil, !queue.isEmpty else { return }
        let job = queue.removeFirst()
        guard peripheral?.state == .connected, characteristic != nil else {
            job.1(false); startNext(); return
        }
        pending = job.0; completion = job.1; next()
    }
    var supportsLive: Bool {
        guard let peripheral, let characteristic else { return false }
        return peripheral.state == .connected && characteristic.properties.contains(.writeWithoutResponse)
            && peripheral.maximumWriteValueLength(for: .withoutResponse) >= 17
    }
    func sendLive(_ data: Data) -> Bool {
        guard completion == nil, queue.isEmpty, let peripheral, let characteristic,
              peripheral.state == .connected, peripheral.canSendWriteWithoutResponse,
              characteristic.properties.contains(.writeWithoutResponse),
              data.count <= peripheral.maximumWriteValueLength(for: .withoutResponse) else { return false }
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        return true
    }
    private func next() {
        guard !pending.isEmpty else { finish(true); return }
        guard let peripheral, let characteristic else { finish(false); return }
        peripheral.writeValue(pending.removeFirst(), for: characteristic, type: .withResponse)
    }
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { finish(false) } else { next() }
    }
    private func finish(_ success: Bool) { pending.removeAll(); let callback = completion; completion = nil; callback?(success); startNext() }
}
