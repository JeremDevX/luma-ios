@preconcurrency import Network
import Foundation

@MainActor final class OBDClient {
    var onRPM: ((Int) -> Void)?
    var onStale: (() -> Void)?
    var onStatus: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    private var connection: NWConnection?
    private var generation = 0
    private var buffer = Data()
    private var timeout: Task<Void, Never>?
    private var poll: Task<Void, Never>?
    private var stale: Task<Void, Never>?
    private var step = 0
    private let setup = ["ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATSP0"]

    static func parseRPM(_ response: String) -> Int? {
        for line in response.uppercased().components(separatedBy: .newlines) {
            let compact = line.filter { !$0.isWhitespace }
            guard !compact.isEmpty, compact.allSatisfy(\.isHexDigit),
                  let marker = compact.range(of: "410C") else { continue }
            let suffix = compact[marker.upperBound...]
            guard suffix.count >= 4, let value = UInt16(suffix.prefix(4), radix: 16) else { continue }
            return Int(value) / 4
        }
        return nil
    }

    func connect(host: String, port: UInt16 = 35000) {
        stop()
        generation += 1
        let id = generation
        guard let port = NWEndpoint.Port(rawValue: port) else { onFailure?("Port OBD invalide."); return }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        self.connection = connection; step = 0; buffer.removeAll()
        onStatus?("Connexion au simulateur…")
        connection.stateUpdateHandler = { [weak self] state in
            let action: Int
            switch state { case .ready: action = 1; case .failed, .cancelled: action = 2; default: return }
            Task { @MainActor in self?.connectionState(action, id: id) }
        }
        connection.start(queue: .main)
        armTimeout(id, seconds: 8)
    }

    func stop() {
        generation += 1
        timeout?.cancel(); timeout = nil
        poll?.cancel(); poll = nil
        stale?.cancel(); stale = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel(); connection = nil
        buffer.removeAll()
    }

    private func connectionState(_ action: Int, id: Int) {
        guard id == generation else { return }
        if action == 2 { fail("Connexion au simulateur OBD interrompue."); return }
        onStatus?("Initialisation OBD…")
        receive(id)
        send(setup[0], id: id)
    }

    private func send(_ command: String, id: Int) {
        guard id == generation, let connection else { return }
        armTimeout(id, seconds: 4)
        connection.send(content: Data((command + "\r").utf8), completion: .contentProcessed { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in if self?.generation == id { self?.fail("Envoi OBD impossible.") } }
        })
    }

    private func receive(_ id: Int) {
        guard id == generation, let connection else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, complete, error in
            let ended = complete || error != nil
            Task { @MainActor in self?.consume(data, ended: ended, id: id) }
        }
    }

    private func consume(_ data: Data?, ended: Bool, id: Int) {
        guard id == generation else { return }
        if let data { buffer.append(data) }
        guard buffer.count <= 4096 else { fail("Réponse OBD trop longue."); return }
        while let end = buffer.firstIndex(of: 0x3e) {
            let responseData = buffer.prefix(upTo: end)
            let response = String(data: responseData, encoding: .ascii) ?? ""
            buffer.removeSubrange(...end)
            timeout?.cancel()
            handle(response, id: id)
            guard id == generation else { return }
        }
        if ended { fail("Connexion au simulateur OBD interrompue.") }
        else { receive(id) }
    }

    private func handle(_ response: String, id: Int) {
        if step < setup.count {
            let text = response.uppercased()
            guard step == 0 ? text.contains("ELM") : text.contains("OK") else {
                fail("Le simulateur n’a pas accepté l’initialisation OBD."); return
            }
            step += 1
            if step < setup.count { send(setup[step], id: id) }
            else { onStatus?("Lecture du régime…"); send("010C", id: id) }
        } else {
            guard let rpm = Self.parseRPM(response) else { fail("Régime moteur indisponible ou réponse OBD invalide."); return }
            onRPM?(rpm)
            stale?.cancel()
            stale = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(1400)) } catch { return }
                if self?.generation == id { self?.onStale?() }
            }
            poll?.cancel()
            poll = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
                self?.send("010C", id: id)
            }
        }
    }

    private func armTimeout(_ id: Int, seconds: Int) {
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard self?.generation == id else { return }
            self?.fail("Le simulateur OBD ne répond pas.")
        }
    }

    private func fail(_ message: String) {
        let callback = onFailure
        stop()
        callback?(message)
    }
}
