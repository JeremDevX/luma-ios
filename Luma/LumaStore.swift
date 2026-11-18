import Foundation
import AVFoundation
import Observation

@MainActor @Observable
final class LumaStore {
    var session: Session = .selection
    var tab: EditorTab = .message
    var sheet: LumaSheet?
    var draft: Draft { didSet { save() } }
    var storageError: String?
    let transcription = LiveTranscription()
    private(set) var obdActive = false
    private(set) var obdRPM: Int?
    private(set) var obdStatus = "Arrêté"
    @ObservationIgnored private let obd = OBDClient()
    @ObservationIgnored private var obdMaximum = 6000
    private(set) var visualizerActive = false
    private(set) var visualizerStarting = false
    private(set) var visualizerLevels = [UInt8](repeating: 0, count: 32)
    var isDrawing = false
    var selectedDrawing: DrawingFavorite?
    var drawingFavorites: [DrawingFavorite] = [] { didSet { saveDrawingFavorites() } }
    var drawing: [Bool] = Array(repeating: false, count: 256) {
        didSet { defaults.set(drawing, forKey: "luma.drawing.v2") }
    }
    private(set) var displayedDrawing: [Bool]?
    private(set) var displayedDraft: Draft?
    private(set) var displayedIcon = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bluetooth = LumaBluetooth()
    @ObservationIgnored private let audio = AudioVisualizer()
    @ObservationIgnored private var visualizerRequested = false
    private static let storageKey = "luma.draft.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let drawingKey = defaults.object(forKey: "luma.drawing.v2") != nil ? "luma.drawing.v2" : "luma.drawing.v1"
        if let saved = defaults.object(forKey: drawingKey) {
            if let pixels = saved as? [Bool], let restored = Self.expandDrawing(pixels) { drawing = restored }
            else { storageError = "Le dessin enregistré n’a pas pu être restauré." }
        }
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                let saved = try JSONDecoder().decode(Draft.self, from: data)
                guard (0...100).contains(saved.brightness), saved.message.count <= 1024,
                      saved.favorites.count <= 20,
                      saved.favorites.allSatisfy({ PixelRenderer.validationError($0) == nil }) else {
                    throw CocoaError(.coderReadCorrupt)
                }
                draft = saved
            } catch {
                draft = Draft()
                storageError = "Les réglages enregistrés n’ont pas pu être restaurés."
            }
        } else {
            draft = Draft()
        }
        let favoritesKey = defaults.object(forKey: "luma.drawingFavorites.v2") != nil
            ? "luma.drawingFavorites.v2" : "luma.drawingFavorites.v1"
        if let stored = defaults.object(forKey: favoritesKey) {
            do {
                guard let data = stored as? Data else { throw CocoaError(.coderReadCorrupt) }
                let saved = try JSONDecoder().decode([DrawingFavorite].self, from: data)
                guard saved.count <= 20, Set(saved.map(\.id)).count == saved.count,
                      saved.allSatisfy({ ($0.pixels.count == 64 || $0.pixels.count == 256) && $0.pixels.contains(true) }) else {
                    throw CocoaError(.coderReadCorrupt)
                }
                drawingFavorites = saved.map { DrawingFavorite(id: $0.id, pixels: Self.expandDrawing($0.pixels)!, color: $0.color) }
            } catch {
                storageError = "Tes dessins favoris n’ont pas pu être restaurés."
            }
        }
    }

    private static func expandDrawing(_ pixels: [Bool]) -> [Bool]? {
        if pixels.count == 256 { return pixels }
        guard pixels.count == 64 else { return nil }
        var expanded = Array(repeating: false, count: 256)
        for index in pixels.indices { expanded[(index / 8) * 32 + 12 + index % 8] = pixels[index] }
        return expanded
    }

    var panel: Panel {
        switch session {
        case .pairing(let panel), .ready(let panel), .offline(let panel): panel
        default: .rgb
        }
    }

    var isReady: Bool { if case .ready = session { true } else { false } }

    func connect(_ panel: Panel) {
        session = .pairing(panel)
        bluetooth.onReady = { [weak self] in
            guard let self else { return }
            self.session = .ready(panel)
            self.syncClock()
        }
        bluetooth.onError = { [weak self] message in
            guard let self, self.session != .selection else { return }
            self.stopVisualizer(sendCommand: false)
            self.stopOBD(sendCommand: false)
            self.stopTranscription(sendCommand: false)
            self.storageError = message
            self.session = .offline(panel)
        }
        bluetooth.connect()
    }

    func startOBD(host: String, maximum: Int) {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        guard isReady, !obdActive else { return }
        guard !host.isEmpty, host.count <= 253, host.unicodeScalars.allSatisfy(allowed.contains),
              (1000...12000).contains(maximum) else { storageError = "Adresse ou régime maximal invalide."; return }
        guard bluetooth.supportsLive else { storageError = "Mets le programme du panneau à jour."; return }
        stopVisualizer()
        stopTranscription()
        obdActive = true; obdRPM = nil; obdMaximum = maximum; obdStatus = "Préparation…"
        obd.onStatus = { [weak self] status in self?.obdStatus = status }
        obd.onRPM = { [weak self] rpm in
            guard let self, self.obdActive else { return }
            self.obdRPM = rpm; self.obdStatus = "Données simulées"
            self.transmitRPM(rpm)
        }
        obd.onStale = { [weak self] in
            guard let self, self.obdActive else { return }
            self.obdRPM = nil; self.obdStatus = "Données en attente…"
        }
        obd.onFailure = { [weak self] message in
            guard let self, self.obdActive else { return }
            self.stopOBD(); self.obdStatus = message
        }
        bluetooth.send([PixelRenderer.displaySettingsPacket(draft), Data([0x61, 1])]) { [weak self] success in
            guard let self, self.obdActive else { return }
            if success { self.obd.connect(host: host) }
            else { self.stopOBD(sendCommand: false); self.obdStatus = "Activation Bluetooth impossible." }
        }
    }

    func setOBDMaximum(_ value: Int) {
        guard (1000...12000).contains(value) else { return }
        obdMaximum = value
        if obdActive, let obdRPM { transmitRPM(obdRPM) }
    }

    private func transmitRPM(_ rpm: Int) {
        guard (0...16383).contains(rpm) else { return }
        _ = bluetooth.sendLive(Data([0x60, UInt8(rpm & 255), UInt8((rpm >> 8) & 255),
                                     UInt8(obdMaximum & 255), UInt8((obdMaximum >> 8) & 255)]))
    }

    func stopOBD(sendCommand: Bool = true) {
        guard obdActive else { return }
        obdActive = false; obdRPM = nil; obdStatus = "Arrêté"
        obd.stop()
        if sendCommand && isReady { bluetooth.send([Data([0x61, 0])]) { _ in } }
    }

    func startVisualizer() async {
        guard isReady, !visualizerRequested else { return }
        guard bluetooth.supportsLive else {
            storageError = "Le panneau ne prend pas en charge le visualiseur audio. Mets son programme à jour."
            return
        }
        stopOBD()
        stopTranscription()
        visualizerRequested = true
        visualizerStarting = true
        let granted = await AVAudioApplication.requestRecordPermission()
        guard visualizerRequested, isReady else { visualizerStarting = false; return }
        guard granted else {
            visualizerRequested = false; visualizerStarting = false
            storageError = "Autorise le microphone dans Réglages pour utiliser le visualiseur."
            return
        }
        bluetooth.send([PixelRenderer.displaySettingsPacket(draft), Data([0x51, 1])]) { [weak self] success in
            guard let self, self.visualizerRequested else { return }
            self.visualizerStarting = false
            guard success else {
                self.visualizerRequested = false
                self.storageError = "Impossible d’activer le visualiseur Bluetooth."
                return
            }
            do {
                try self.audio.start { [weak self] levels in
                    guard let self, self.visualizerActive else { return }
                    self.visualizerLevels = levels
                    var packet: [UInt8] = [0x50]
                    for index in stride(from: 0, to: 32, by: 2) {
                        packet.append((levels[index] << 4) | levels[index + 1])
                    }
                    _ = self.bluetooth.sendLive(Data(packet))
                }
                self.visualizerActive = true
            } catch {
                self.audio.stop()
                self.visualizerRequested = false
                self.bluetooth.send([Data([0x51, 0])]) { _ in }
                self.storageError = "Impossible d’utiliser le microphone. Vérifie les réglages audio."
            }
        }
    }

    func stopVisualizer(sendCommand: Bool = true) {
        guard visualizerRequested || visualizerActive || visualizerStarting else { return }
        visualizerRequested = false; visualizerStarting = false; visualizerActive = false
        audio.stop()
        visualizerLevels = Array(repeating: 0, count: 32)
        if sendCommand && isReady { bluetooth.send([Data([0x51, 0])]) { _ in } }
    }

    func startTranscription() async {
        guard isReady, !transcription.isRunning else { return }
        stopVisualizer()
        stopOBD()
        await transcription.start { [weak self] message, completion in
            guard let self, self.isReady else { completion(false); return }
            let packets = [PixelRenderer.displaySettingsPacket(self.draft), Data([0x46, 0]), Data([0x47, 0])]
                + PixelRenderer.scrollPackets(message, speed: .fast)
            self.bluetooth.send(packets, completion: completion)
        } onClear: { [weak self] in
            guard let self, self.isReady else { return }
            let empty = Array(repeating: Array(repeating: false, count: 32), count: 8)
            self.bluetooth.send(PixelRenderer.framePackets(empty)) { _ in }
        }
    }

    func stopTranscription(sendCommand: Bool = true) {
        transcription.stop(clearPanel: sendCommand && isReady)
    }

    private func syncClock() {
        let now = Date()
        let seconds = Int64(now.timeIntervalSince1970) + Int64(TimeZone.current.secondsFromGMT(for: now))
        guard seconds >= 0, seconds <= Int64(UInt32.max) else { storageError = "Impossible de synchroniser l’heure."; return }
        let value = UInt32(seconds)
        bluetooth.send([Data([0x41, UInt8(value & 255), UInt8((value >> 8) & 255),
                              UInt8((value >> 16) & 255), UInt8((value >> 24) & 255)])]) { [weak self] success in
            if !success { self?.storageError = "Synchronisation de l’heure impossible." }
        }
    }

    func sendMode(_ mode: Int, seconds: Int = 0) {
        guard (1...9).contains(mode), (0...5999).contains(seconds), mode != 3 || seconds > 0 else { return }
        stopVisualizer()
        stopOBD()
        stopTranscription()
        let value = UInt32(seconds)
        sendFeature([
            PixelRenderer.displaySettingsPacket(draft),
            Data([0x40, UInt8(mode), UInt8(value & 255), UInt8((value >> 8) & 255),
                  UInt8((value >> 16) & 255), UInt8((value >> 24) & 255)])
        ])
    }

    func controlMode(_ action: UInt8) { sendFeature([Data([0x42, action])]) }

    func scheduleMessage(index: Int, hour: Int, minute: Int, text: String) {
        let normalized = PixelRenderer.normalize(text)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 :/")
        guard (0...1).contains(index), (0...23).contains(hour), (0...59).contains(minute),
              normalized.utf8.count <= 16, normalized.unicodeScalars.allSatisfy(allowed.contains) else {
            storageError = "Utilise 16 lettres sans accents, chiffres ou espaces maximum."
            return
        }
        var data = Data([0x44, UInt8(index), UInt8(hour), UInt8(minute)])
        data.append(contentsOf: normalized.utf8)
        sendFeature([data])
    }

    private func sendFeature(_ packets: [Data]) {
        guard isReady else { storageError = "Connecte le panneau avant d’envoyer la commande."; return }
        bluetooth.send(packets) { [weak self] success in
            if success { self?.sheet = .feature }
            else { self?.storageError = "Envoi Bluetooth impossible." }
        }
    }

    private func sendCurrent(completion: @escaping (Bool) -> Void) {
        let content = displayedDraft ?? draft
        var packets = [PixelRenderer.displaySettingsPacket(content), Data([0x46, 0])]
        let validMessage = content.isOn && !displayedIcon && PixelRenderer.validationError(content.message) == nil
        if validMessage && content.scrollMode == .appearance {
            packets.append(contentsOf: PixelRenderer.appearancePackets(content.message, panel: panel, speed: content.speed))
        } else if validMessage && PixelRenderer.shouldScroll(content.message, panel: panel, mode: content.scrollMode) {
            packets.append(Data([0x47, 0]))
            packets.append(contentsOf: PixelRenderer.scrollPackets(content.message, speed: content.speed))
        } else {
            packets.append(Data([0x47, 0]))
            let grid = PixelRenderer.grid(draft: content, panel: panel, icon: displayedIcon, drawing: displayedDrawing)
            packets.append(contentsOf: PixelRenderer.framePackets(grid))
        }
        bluetooth.send(packets, completion: completion)
    }

    func toggleFavorite() {
        let text = PixelRenderer.normalize(draft.message)
        guard PixelRenderer.validationError(text) == nil else { return }
        if let index = draft.favorites.firstIndex(of: text) { draft.favorites.remove(at: index) }
        else {
            guard draft.favorites.count < 20 else { return }
            draft.favorites.append(text)
        }
    }

    func display() {
        guard isReady, tab == .icons || PixelRenderer.validationError(draft.message) == nil else { return }
        stopVisualizer()
        stopOBD()
        stopTranscription()
        draft.isOn = true
        displayedDraft = draft
        displayedIcon = tab == .icons
        displayedDrawing = displayedIcon ? (isDrawing ? drawing : selectedDrawing?.pixels) : nil
        sendCurrent { [weak self] success in
            if success { self?.sheet = .sent }
            else { self?.storageError = "Envoi Bluetooth impossible." }
        }
    }

    func apply() {
        guard isReady else { return }
        stopVisualizer()
        stopOBD()
        stopTranscription()
        if displayedDraft != nil {
            displayedDraft?.brightness = draft.brightness
            displayedDraft?.scrollMode = draft.scrollMode
            displayedDraft?.speed = draft.speed
            displayedDraft?.isOn = draft.isOn
        }
        sendCurrent { [weak self] success in
            if success { self?.sheet = .applied }
            else { self?.storageError = "Envoi Bluetooth impossible." }
        }
    }

    func clear() {
        stopVisualizer()
        stopOBD()
        stopTranscription()
        draft.isOn = false
        displayedDraft = nil
        displayedDrawing = nil
        sheet = nil
        sendCurrent { [weak self] success in if !success { self?.storageError = "Effacement Bluetooth impossible." } }
    }

    func disconnect() {
        stopVisualizer()
        stopOBD()
        stopTranscription()
        session = .selection
        bluetooth.stop()
        tab = .message
        sheet = nil
    }

    func clearDrawing() {
        drawing = Array(repeating: false, count: 256)
        sheet = nil
    }

    var isDrawingFavorite: Bool {
        drawingFavorites.contains { $0.pixels == drawing && $0.color == draft.color }
    }

    func validateDrawing() {
        guard drawing.contains(true) else { return }
        selectedDrawing = drawingFavorites.first { $0.pixels == drawing && $0.color == draft.color }
            ?? DrawingFavorite(pixels: drawing, color: draft.color)
        isDrawing = false
    }

    func toggleDrawingFavorite() {
        if let index = drawingFavorites.firstIndex(where: { $0.pixels == drawing && $0.color == draft.color }) {
            drawingFavorites.remove(at: index)
        } else {
            guard drawing.contains(true), drawingFavorites.count < 20 else { return }
            drawingFavorites.append(DrawingFavorite(pixels: drawing, color: draft.color))
        }
    }

    func selectDrawing(_ favorite: DrawingFavorite) {
        drawing = favorite.pixels
        draft.color = favorite.color
        selectedDrawing = favorite
        isDrawing = false
    }

    private func saveDrawingFavorites() {
        do { defaults.set(try JSONEncoder().encode(drawingFavorites), forKey: "luma.drawingFavorites.v2") }
        catch { storageError = "Tes dessins favoris n’ont pas pu être enregistrés." }
    }

    private func save() {
        do { defaults.set(try JSONEncoder().encode(draft), forKey: Self.storageKey) }
        catch { storageError = "Tes réglages n’ont pas pu être enregistrés." }
    }
}
