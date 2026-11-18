@preconcurrency import AVFoundation
@preconcurrency import Speech
import Foundation
import Observation

@MainActor @Observable
final class LiveTranscription {
    private(set) var isRunning = false
    private(set) var text = ""
    private(set) var status = "Arrêtée"
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var recognizer: SFSpeechRecognizer?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognition: SFSpeechRecognitionTask?
    @ObservationIgnored private var flushTask: Task<Void, Never>?
    @ObservationIgnored private var displayTask: Task<Void, Never>?
    @ObservationIgnored private var restartTask: Task<Void, Never>?
    @ObservationIgnored private var queue: [String] = []
    @ObservationIgnored private var words: [String] = []
    @ObservationIgnored private var history = ""
    @ObservationIgnored private var emitted = 0
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var recognitionGeneration = 0
    @ObservationIgnored private var installed = false
    @ObservationIgnored private var sending = false
    @ObservationIgnored private var send: ((String, @escaping (Bool) -> Void) -> Void)?
    @ObservationIgnored private var clear: (() -> Void)?

    func start(send: @escaping (String, @escaping (Bool) -> Void) -> Void, onClear: @escaping () -> Void) async {
        guard !isRunning else { return }
        isRunning = true; generation += 1
        let run = generation
        status = "Autorisation du micro…"; text = ""; history = ""
        let microphone = await AVAudioApplication.requestRecordPermission()
        guard isRunning, generation == run else { return }
        guard microphone else { fail("Autorise le microphone dans les réglages de l’iPhone."); return }
        let permission = await Self.speechAuthorization { callback in
            SFSpeechRecognizer.requestAuthorization(callback)
        }
        guard isRunning, generation == run else { return }
        guard permission == .authorized else { fail("Autorise la reconnaissance vocale dans les réglages de l’iPhone."); return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            fail("Reconnaissance française sur l’iPhone indisponible."); return
        }
        self.recognizer = recognizer; self.send = send; self.clear = onClear
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            guard let microphone = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
                throw CocoaError(.featureUnsupported)
            }
            try session.setPreferredInput(microphone)
            try beginRecognition(run: run)
            status = "À l’écoute · traitement sur l’iPhone"
        } catch { fail("Impossible de démarrer la reconnaissance vocale.") }
    }

    nonisolated static func speechAuthorization(
        _ register: @Sendable (@escaping @Sendable (SFSpeechRecognizerAuthorizationStatus) -> Void) -> Void
    ) async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            register { continuation.resume(returning: $0) }
        }
    }

    private func beginRecognition(run: Int) throws {
        recognitionGeneration += 1
        let currentRecognition = recognitionGeneration
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request
        guard let recognizer else { throw CocoaError(.featureUnsupported) }
        recognition = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let phrase = result?.bestTranscription.formattedString
            let final = result?.isFinal ?? false
            let failure = error.map { (($0 as NSError).domain, ($0 as NSError).code) }
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, self.generation == run,
                      self.recognitionGeneration == currentRecognition else { return }
                if let phrase { self.accept(phrase, final: final) }
                if final { self.restart(run: run) }
                else if let failure {
                    if failure.0 == "kAFAssistantErrorDomain", failure.1 == 1110 {
                        self.status = "À l’écoute · en attente de parole"
                        if !self.words.isEmpty { self.accept(self.words.joined(separator: " "), final: true) }
                        self.restart(run: run)
                    } else {
                        self.fail("La reconnaissance vocale s’est interrompue. Relance-la.")
                    }
                }
            }
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CocoaError(.featureUnsupported) }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            request.append(buffer)
        }
        installed = true
        engine.prepare(); try engine.start()
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(50))
            guard !Task.isCancelled, let self, self.isRunning, self.generation == run else { return }
            self.accept(self.words.joined(separator: " "), final: true)
            self.restart(run: run)
        }
    }

    private func restart(run: Int) {
        guard isRunning, generation == run else { return }
        stopRecognition()
        words = []; emitted = 0
        do { try beginRecognition(run: run) }
        catch { fail("Impossible de reprendre la reconnaissance vocale.") }
    }

    private func accept(_ phrase: String, final: Bool) {
        text = Self.transcript(history: history, phrase: phrase)
        if final { history = text }
        words = phrase.split(whereSeparator: \.isWhitespace).map(String.init)
        emitted = min(emitted, words.count)
        enqueueWords(upTo: final ? words.count : max(0, words.count - 1))
        flushTask?.cancel()
        if !final {
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled, let self, self.isRunning else { return }
                self.enqueueWords(upTo: self.words.count)
            }
        }
    }

    static func transcript(history: String, phrase: String) -> String {
        let parts = [history, phrase].filter { !$0.isEmpty }
        return String(parts.joined(separator: " ").suffix(500))
    }

    private func enqueueWords(upTo end: Int) {
        guard end > emitted else { return }
        for word in words[emitted..<end] {
            let cleaned = Array(Self.clean(word))
            for start in stride(from: 0, to: cleaned.count, by: 55) {
                queue.append(String(cleaned[start..<min(start + 55, cleaned.count)]))
            }
        }
        emitted = end
        if Self.trimQueue(&queue) { status = "À l’écoute · certains mots ignorés" }
        else if queue.joined(separator: " ").count > 150 { status = "À l’écoute · affichage en retard" }
        showNext()
    }

    static func clean(_ word: String) -> String {
        let folded = PixelRenderer.normalize(word.replacingOccurrences(of: "’", with: "'"))
        return String(folded.map { character in
            if PixelFont.glyphs[String(character)] != nil { return character }
            let base = String(character).folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            return base.count == 1 && PixelFont.glyphs[base] != nil ? Character(base) : " "
        }).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func trimQueue(_ queue: inout [String]) -> Bool {
        var dropped = false
        while queue.joined(separator: " ").count > 800 && queue.count > 1 {
            queue.removeFirst(); dropped = true
        }
        return dropped
    }

    static func takeBatch(_ queue: inout [String]) -> String {
        guard !queue.isEmpty else { return "" }
        var batch = queue.removeFirst()
        while let next = queue.first, batch.count + next.count + 1 <= 55 {
            batch += " " + queue.removeFirst()
        }
        return batch
    }

    private func showNext() {
        guard isRunning, !sending, !queue.isEmpty, let send else { return }
        let batch = Self.takeBatch(&queue)
        sending = true
        let run = generation
        send(batch) { [weak self] success in
            guard let self, self.isRunning, self.generation == run else { return }
            guard success else { self.fail("Envoi Bluetooth impossible."); return }
            let duration = Double(32 + batch.count * 6 - 1 + 6) * Speed.fast.interval
            self.displayTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled, let self, self.isRunning, self.generation == run else { return }
                self.sending = false
                if self.queue.isEmpty { self.status = "À l’écoute · traitement sur l’iPhone" }
                if self.queue.isEmpty { self.clear?() } else { self.showNext() }
            }
        }
    }

    private func stopRecognition() {
        recognitionGeneration += 1
        restartTask?.cancel(); restartTask = nil
        engine.stop()
        if installed { engine.inputNode.removeTap(onBus: 0); installed = false }
        request?.endAudio(); request = nil
        recognition?.cancel(); recognition = nil
    }

    private func fail(_ message: String) { stop(clearPanel: true); status = message }

    func stop(clearPanel: Bool = true) {
        guard isRunning else { return }
        isRunning = false; generation += 1
        flushTask?.cancel(); displayTask?.cancel(); stopRecognition()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        queue.removeAll(); words.removeAll(); emitted = 0; sending = false
        if clearPanel { clear?() }
        send = nil; clear = nil; recognizer = nil
        status = "Arrêtée"
    }
}
