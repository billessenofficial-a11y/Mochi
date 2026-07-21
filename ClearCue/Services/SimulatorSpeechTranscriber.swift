#if targetEnvironment(simulator)
@preconcurrency import AVFoundation
import Foundation
@preconcurrency import Speech

/// Development-only caption path. The iOS Simulator cannot reliably load the
/// Whisper Core ML graph, so it uses Apple's recognizer while physical devices
/// continue to use WhisperKit. No extra package or production code path is added.
@MainActor
final class SimulatorSpeechTranscriber {
    enum SimulatorSpeechError: LocalizedError {
        case permissionDenied
        case unavailable

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Speech recognition access is required for live captions in Simulator."
            case .unavailable:
                "The Simulator speech recognizer is unavailable. Try again or run Mochi on an iPhone."
            }
        }
    }

    private let emit: (FluidAudioEvent) -> Void
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentText = ""
    private var utteranceID = "sim-\(UUID().uuidString)"
    private var utteranceStartedAt = Date()
    private var levelEmissionCounter = 0

    init(emit: @escaping (FluidAudioEvent) -> Void) {
        self.emit = emit
    }

    func requestPermission() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else { throw SimulatorSpeechError.permissionDenied }
    }

    func start() throws {
        recognitionTask?.cancel()
        request = nil
        guard let recognizer, recognizer.isAvailable else {
            throw SimulatorSpeechError.unavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // Simulator runtimes can report local recognition support even when
        // their bundled speech asset cannot be loaded. Use Apple's network
        // recognizer here; physical devices continue to use on-device Whisper.
        request.requiresOnDeviceRecognition = false
        self.request = request
        currentText = ""
        levelEmissionCounter = 0
        utteranceID = "sim-\(UUID().uuidString)"
        utteranceStartedAt = Date()

        recognitionTask = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let text = result?.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isFinal = result?.isFinal ?? false
            let hadError = error != nil

            Task { @MainActor [weak self] in
                self?.handleRecognition(text: text, isFinal: isFinal, hadError: hadError)
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
        levelEmissionCounter += 1
        if levelEmissionCounter >= 4 {
            levelEmissionCounter = 0
            emit(.audioLevel(Self.normalizedLevel(for: buffer)))
        }
    }

    func finish() {
        request?.endAudio()
        commitCurrentText()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
    }

    func cancel() {
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        currentText = ""
        levelEmissionCounter = 0
        emit(.audioLevel(0))
        emit(.partial(""))
    }

    private func commitCurrentText() {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            emit(.partial(""))
            return
        }
        emit(
            .utterance(
                RecognizedUtterance(
                    id: utteranceID,
                    text: text,
                    speakerIndex: 0,
                    startSeconds: max(0, -utteranceStartedAt.timeIntervalSinceNow),
                    isRevision: false
                )
            )
        )
        currentText = ""
        utteranceID = "sim-\(UUID().uuidString)"
        utteranceStartedAt = Date()
        emit(.partial(""))
    }

    private func handleRecognition(text: String, isFinal: Bool, hadError: Bool) {
        guard !text.isEmpty else {
            if hadError {
                commitCurrentText()
            }
            return
        }

        currentText = text
        emit(.partial(text))
        if isFinal {
            commitCurrentText()
        }
    }

    private static func normalizedLevel(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData,
              buffer.frameLength > 0 else { return 0 }

        let samples = channels[0]
        let count = Int(buffer.frameLength)
        var sumOfSquares: Float = 0
        for index in 0..<count {
            let sample = samples[index]
            sumOfSquares += sample * sample
        }

        let rms = sqrt(sumOfSquares / Float(count))
        let decibels = 20 * log10(max(rms, 0.000_001))
        return min(max((decibels + 60) / 60, 0), 1)
    }
}
#endif
