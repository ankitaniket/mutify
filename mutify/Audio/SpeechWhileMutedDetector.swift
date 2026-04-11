import Foundation
import AVFoundation
import Combine

/// Detects sustained voice activity while the user is muted, and pings a
/// callback so the UI can show a "You're muted!" hint.
///
/// Strictly opt-in via `Preferences.speakingDetectionEnabled`. The audio
/// frames captured by `AVAudioEngine` are RMS-analyzed locally and never
/// stored or transmitted.
///
/// Caveat: when Mutify hard-mutes the device via
/// `kAudioDevicePropertyMute`, some drivers feed silence to every client
/// (including this one), in which case detection naturally won't fire.
/// Most built-in mics still pass frames through and detection works.
final class SpeechWhileMutedDetector {
    static let shared = SpeechWhileMutedDetector()

    /// Fires (on main) once per "speaking session" while muted.
    var onSpeakingDetected: (() -> Void)?
    /// Fires (on main) when the user has been silent for a while again.
    var onSilenceResumed: (() -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false
    private var cancellables = Set<AnyCancellable>()

    // Tunables
    private let rmsThreshold: Float = 0.02     // ~ -34 dBFS
    private let speakingFramesNeeded = 8       // ~0.5s @ 100ms buckets
    private let silenceFramesNeeded = 20       // ~2.0s
    private var consecutiveLoud = 0
    private var consecutiveQuiet = 0
    private var currentlySpeaking = false

    private init() {}

    func start() {
        // React to user toggling the feature on/off.
        Preferences.shared.$speakingDetectionEnabled
            .combineLatest(MicrophoneController.shared.$isMuted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled, muted in
                if enabled && muted {
                    self?.startEngine()
                } else {
                    self?.stopEngine()
                    self?.resetCounters()
                    if self?.currentlySpeaking == true {
                        self?.currentlySpeaking = false
                        self?.onSilenceResumed?()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func startEngine() {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { return }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
        } catch {
            NSLog("Mutify: speech detector failed to start engine: \(error)")
        }
    }

    private func stopEngine() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func resetCounters() {
        consecutiveLoud = 0
        consecutiveQuiet = 0
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        let samples = channelData[0]
        var sumSquares: Float = 0
        for i in 0..<frameLength {
            let s = samples[i]
            sumSquares += s * s
        }
        let rms = sqrtf(sumSquares / Float(frameLength))

        DispatchQueue.main.async { [weak self] in
            self?.evaluate(rms: rms)
        }
    }

    private func evaluate(rms: Float) {
        if rms >= rmsThreshold {
            consecutiveLoud += 1
            consecutiveQuiet = 0
            if !currentlySpeaking, consecutiveLoud >= speakingFramesNeeded {
                currentlySpeaking = true
                onSpeakingDetected?()
            }
        } else {
            consecutiveQuiet += 1
            consecutiveLoud = 0
            if currentlySpeaking, consecutiveQuiet >= silenceFramesNeeded {
                currentlySpeaking = false
                onSilenceResumed?()
            }
        }
    }
}
