@preconcurrency import AVFoundation
import CoreML
@preconcurrency import FluidAudio
import Foundation
import OSLog
@preconcurrency import WhisperKit

/// Runs OpenAI Whisper fully on-device through WhisperKit. Mochi owns the
/// microphone tap so the exact same audio can be recorded, diarized, and
/// captioned without competing AVAudioEngine instances.
actor WhisperKitCaptionTranscriber {
    private static let logger = Logger(subsystem: "com.jamesangrellera.clearcue", category: "WhisperSetup")
    enum CaptionError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "On-device Whisper captions could not be prepared. Check the network for the first model download and try again."
        }
    }

    private struct PendingDecode {
        let samples: [Float]
        let startSeconds: TimeInterval
        let speakerIndex: Int
        let isFinal: Bool
        let generation: Int
    }

    private let emit: @Sendable (FluidAudioEvent) -> Void
    private let converter = AudioConverter()
    private var whisperKit: WhisperKit?
    private var isPreparing = false
    private var isDecoding = false
    private var pendingFinal: PendingDecode?

    private var sampleClock = 0
    private var preRoll: [Float] = []
    private var utteranceSamples: [Float] = []
    private var utteranceStartSeconds: TimeInterval = 0
    private var trailingSilenceSamples = 0
    private var lastPartialSampleCount = 0
    private var currentSpeakerIndex = 0
    private var utteranceNumber = 0
    private var generation = 0

    private let sampleRate = 16_000
    private let speechThreshold: Float = 0.009
    private let preRollSampleCount = 4_000
    private let silenceToFinalize = 10_400
    private let partialInterval = 19_200
    private let maximumUtteranceSamples = 320_000

    /// Keep Simulator iteration fast with multilingual tiny. Physical iPhones
    /// retain the more accurate multilingual base model for code-switching.
    private static var modelVariant: String {
        #if targetEnvironment(simulator)
        "tiny"
        #else
        "base"
        #endif
    }

    init(emit: @escaping @Sendable (FluidAudioEvent) -> Void) {
        self.emit = emit
    }

    func prepare() async throws {
        guard whisperKit == nil, !isPreparing else { return }
        isPreparing = true
        defer { isPreparing = false }

        Self.logger.info("Whisper actor preparation started")
        emit(.loading("Preparing the on-device hearing model…", nil))
        let defaultsKey = "mochi.whisperModelFolder.\(Self.modelVariant)"
        let storedFolder = UserDefaults.standard.string(forKey: defaultsKey)
        let modelFolder: URL
        if let storedFolder, Self.isCompleteModelFolder(URL(fileURLWithPath: storedFolder)) {
            modelFolder = URL(fileURLWithPath: storedFolder)
            Self.logger.info("Using saved Whisper model folder")
        } else if let discoveredFolder = Self.discoverCompleteModelFolder() {
            modelFolder = discoveredFolder
            Self.logger.info("Discovered complete Whisper model folder")
        } else {
            Self.logger.info("No complete Whisper model found; beginning foreground download")
            let emit = emit
            // Await the complete Hub snapshot. Treating the first few compiled
            // files as "done" used to cancel the download mid-model, leaving a
            // folder that existed but Core ML could not load.
            modelFolder = try await WhisperKit.download(
                variant: Self.modelVariant,
                useBackgroundSession: false
            ) { progress in
                emit(.loading("Downloading Whisper for on-device hearing…", progress.fractionCompleted))
            }
        }
        UserDefaults.standard.set(modelFolder.path, forKey: defaultsKey)
        emit(.captionModelDownloaded)
        emit(.loading("Optimizing Whisper for this device…", nil))
        Self.logger.info("Loading Core ML Whisper models")
        #if targetEnvironment(simulator)
        let compute = ModelComputeOptions(
            melCompute: .cpuAndGPU,
            audioEncoderCompute: .cpuAndGPU,
            textDecoderCompute: .cpuAndGPU
        )
        #else
        let compute = ModelComputeOptions(
            melCompute: .cpuAndGPU,
            audioEncoderCompute: .cpuAndNeuralEngine,
            textDecoderCompute: .cpuAndNeuralEngine
        )
        #endif
        let config = WhisperKitConfig(
            modelFolder: modelFolder.path,
            computeOptions: compute,
            verbose: false,
            // Direct loading is noticeably faster for a live-caption UI. Core ML
            // still specializes and caches the model on its first real load.
            prewarm: false,
            load: true,
            download: false
        )
        let whisperKit = try await WhisperKit(config)
        self.whisperKit = whisperKit
        Self.logger.info("Core ML Whisper models loaded")
        emit(.captioningReady)
    }

    private static func discoverCompleteModelFolder() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let root = documents
            .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml", isDirectory: true)
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }
        let expectedName = "openai_whisper-\(modelVariant)"
        return folders.first {
            $0.lastPathComponent.caseInsensitiveCompare(expectedName) == .orderedSame && isCompleteModelFolder($0)
        }
    }

    private static func isCompleteModelFolder(_ folder: URL) -> Bool {
        let requiredPaths = [
            "config.json",
            "MelSpectrogram.mlmodelc/model.mil",
            "AudioEncoder.mlmodelc/model.mil",
            "AudioEncoder.mlmodelc/weights/weight.bin",
            "TextDecoder.mlmodelc/model.mil",
            "TextDecoder.mlmodelc/weights/weight.bin"
        ]
        return requiredPaths.allSatisfy {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
    }

    func consume(buffer: sending AVAudioPCMBuffer) {
        guard whisperKit != nil else { return }
        do {
            let samples = try converter.resampleBuffer(buffer)
            consume(samples: samples)
        } catch {
            emit(.captionFailure("Whisper audio conversion failed: \(error.localizedDescription)"))
        }
    }

    func updateSpeaker(_ index: Int) {
        currentSpeakerIndex = max(0, index)
    }

    func finish() async {
        if !utteranceSamples.isEmpty {
            queueFinalDecode()
        }

        while isDecoding || pendingFinal != nil {
            try? await Task.sleep(for: .milliseconds(80))
        }
        emit(.partial(""))
    }

    func resetSession() {
        generation += 1
        sampleClock = 0
        preRoll.removeAll(keepingCapacity: true)
        utteranceSamples.removeAll(keepingCapacity: true)
        trailingSilenceSamples = 0
        lastPartialSampleCount = 0
        pendingFinal = nil
        currentSpeakerIndex = 0
        emit(.partial(""))
    }

    private func consume(samples: [Float]) {
        guard !samples.isEmpty else { return }
        sampleClock += samples.count
        let rms = Self.rootMeanSquare(samples)
        let containsSpeech = rms >= speechThreshold

        if utteranceSamples.isEmpty {
            preRoll.append(contentsOf: samples)
            if preRoll.count > preRollSampleCount {
                preRoll.removeFirst(preRoll.count - preRollSampleCount)
            }

            guard containsSpeech else { return }
            utteranceSamples = preRoll
            utteranceStartSeconds = TimeInterval(max(0, sampleClock - utteranceSamples.count)) / TimeInterval(sampleRate)
            trailingSilenceSamples = 0
            lastPartialSampleCount = 0
            return
        }

        utteranceSamples.append(contentsOf: samples)
        trailingSilenceSamples = containsSpeech ? 0 : trailingSilenceSamples + samples.count

        if !isDecoding,
           utteranceSamples.count >= partialInterval,
           utteranceSamples.count - lastPartialSampleCount >= partialInterval {
            lastPartialSampleCount = utteranceSamples.count
            requestDecode(
                PendingDecode(
                    samples: utteranceSamples,
                    startSeconds: utteranceStartSeconds,
                    speakerIndex: currentSpeakerIndex,
                    isFinal: false,
                    generation: generation
                )
            )
        }

        if trailingSilenceSamples >= silenceToFinalize || utteranceSamples.count >= maximumUtteranceSamples {
            queueFinalDecode()
        }
    }

    private func queueFinalDecode() {
        guard !utteranceSamples.isEmpty else { return }
        let decode = PendingDecode(
            samples: utteranceSamples,
            startSeconds: utteranceStartSeconds,
            speakerIndex: currentSpeakerIndex,
            isFinal: true,
            generation: generation
        )
        utteranceSamples.removeAll(keepingCapacity: true)
        preRoll.removeAll(keepingCapacity: true)
        trailingSilenceSamples = 0
        lastPartialSampleCount = 0

        if isDecoding {
            pendingFinal = decode
        } else {
            requestDecode(decode)
        }
    }

    private func requestDecode(_ decode: PendingDecode) {
        guard !isDecoding else {
            if decode.isFinal { pendingFinal = decode }
            return
        }
        isDecoding = true
        Task { await performDecode(decode) }
    }

    private func performDecode(_ decode: PendingDecode) async {
        defer {
            isDecoding = false
            if let pendingFinal {
                self.pendingFinal = nil
                requestDecode(pendingFinal)
            }
        }

        guard decode.generation == generation, let whisperKit else { return }
        var options = DecodingOptions(
            task: .transcribe,
            language: nil,
            temperature: 0,
            usePrefillPrompt: true,
            detectLanguage: true,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: false,
            chunkingStrategy: .vad
        )
        options.sampleLength = 224

        do {
            let emit = emit
            let results = try await whisperKit.transcribe(
                audioArray: decode.samples,
                decodeOptions: options
            ) { progress in
                let text = Self.captionText(progress.text)
                if !text.isEmpty { emit(.partial(text)) }
                return nil
            }
            guard decode.generation == generation else { return }
            let text = Self.captionText(results.map(\.text).joined(separator: " "))
            guard !text.isEmpty else {
                if decode.isFinal { emit(.partial("")) }
                return
            }

            if decode.isFinal {
                utteranceNumber += 1
                emit(.partial(""))
                emit(.utterance(
                    RecognizedUtterance(
                        id: "whisper-\(generation)-\(utteranceNumber)",
                        text: text,
                        speakerIndex: decode.speakerIndex,
                        startSeconds: decode.startSeconds,
                        isRevision: false
                    )
                ))
            } else {
                emit(.partial(text))
            }
        } catch {
            emit(.captionFailure("Whisper captioning paused: \(error.localizedDescription)"))
        }
    }

    private static func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(Float.zero) { $0 + $1 * $1 } / Float(samples.count)
        return sqrt(meanSquare)
    }

    private static func captionText(_ rawText: String) -> String {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Whisper can produce this control-like placeholder for simulator
        // silence. It is not speech and should never become transcript evidence.
        if text.caseInsensitiveCompare("[BLANK_AUDIO]") == .orderedSame { return "" }
        return text
    }
}
