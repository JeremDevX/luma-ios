import Accelerate
import AVFoundation
import Foundation

final class SpectrumAnalyzer: @unchecked Sendable {
    private let size = 512
    private let setup: vDSP_DFT_Setup
    private var lastFrame: UInt64 = 0
    private let lock = NSLock()
    private var smoothed = [Float](repeating: 0, count: 32)
    private let window: [Float]

    init?() {
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, 512, .FORWARD) else { return nil }
        self.setup = setup
        var window = [Float](repeating: 0, count: 512)
        vDSP_hann_window(&window, 512, Int32(vDSP_HANN_NORM))
        self.window = window
    }

    deinit { vDSP_DFT_DestroySetup(setup) }

    func analyze(_ samples: [Float], sampleRate: Double) -> [UInt8] {
        guard samples.count >= size, sampleRate.isFinite, sampleRate > 0,
              samples.prefix(size).allSatisfy(\.isFinite) else { return Array(repeating: 0, count: 32) }
        var input = [Float](repeating: 0, count: size)
        vDSP_vmul(samples, 1, window, 1, &input, 1, vDSP_Length(size))
        let zero = [Float](repeating: 0, count: size)
        var real = [Float](repeating: 0, count: size)
        var imaginary = [Float](repeating: 0, count: size)
        vDSP_DFT_Execute(setup, input, zero, &real, &imaginary)
        let maximumHz = min(10000.0, sampleRate / 2)
        guard maximumHz > 80 else { return Array(repeating: 0, count: 32) }
        return (0..<32).map { band in
            let low = 80 * pow(maximumHz / 80, Double(band) / 32)
            let high = 80 * pow(maximumHz / 80, Double(band + 1) / 32)
            let first = max(1, min(size / 2 - 1, Int(low * Double(size) / sampleRate)))
            let end = max(first + 1, min(size / 2, Int(ceil(high * Double(size) / sampleRate))))
            var magnitude: Float = 0
            for bin in first..<end {
                magnitude = max(magnitude, hypotf(real[bin], imaginary[bin]) / Float(size))
            }
            let db = 20 * log10f(max(magnitude, 0.000001))
            let target = max(0, min(8, (db + 65) * 8 / 45))
            smoothed[band] = target > smoothed[band] ? target : max(target, smoothed[band] - 0.8)
            return UInt8(smoothed[band].rounded())
        }
    }

    func nextFrame(_ buffer: AVReadOnlyAudioPCMBuffer) -> [UInt8]? {
        guard lock.try() else { return nil }
        defer { lock.unlock() }
        let now = DispatchTime.now().uptimeNanoseconds
        guard now - lastFrame >= 66_000_000, buffer.frameLength >= size,
              buffer.format.channelCount > 0 else { return nil }
        guard case let .float(channel) = buffer.channelData(0), channel.count >= size else { return nil }
        var samples = [Float](); samples.reserveCapacity(size)
        for i in 0..<size { samples.append(channel[i]) }
        lastFrame = now
        return analyze(samples, sampleRate: buffer.format.sampleRate)
    }

}

@MainActor final class AudioVisualizer {
    private let engine = AVAudioEngine()
    private var installed = false

    func start(onFrame: @escaping @MainActor @Sendable ([UInt8]) -> Void) throws {
        guard let analyzer = SpectrumAnalyzer() else { throw CocoaError(.featureUnsupported) }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
        guard let microphone = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            throw CocoaError(.featureUnsupported)
        }
        try session.setPreferredInput(microphone)
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else { throw CocoaError(.featureUnsupported) }
        try input.installAudioTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let levels = analyzer.nextFrame(buffer) else { return }
            Task { @MainActor in onFrame(levels) }
        }
        installed = true
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
        if installed { engine.inputNode.removeTap(onBus: 0); installed = false }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
