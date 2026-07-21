@preconcurrency import AVFoundation
import AudioToolbox
import CoreML
@preconcurrency import FluidAudio
import Foundation
import OSLog

struct RecognizedUtterance: Sendable {
    let id: String
    let text: String
    let speakerIndex: Int
    let startSeconds: TimeInterval
    let isRevision: Bool
}

enum FluidAudioEvent: Sendable {
    case loading(String, Double?)
    case captionModelDownloaded
    case captioningReady
    case realtimeReady
    case diarizationReady
    case audioLevel(Float)
    case partial(String)
    case speaker(Int)
    case utterance(RecognizedUtterance)
    case captionFailure(String)
    case realtimeFailure(String)
    case diarizationFailure(String)
}

/// FluidAudio now owns only speaker diarization. Caption generation runs in a
/// separate actor so Sortformer can never block the latency-critical stream.
private actor DiarizationPipeline {
    private let emit: @Sendable (FluidAudioEvent) -> Void
    private let converter = AudioConverter()
    private var diarizer: SortformerDiarizer?
    private var prepared = false
    private var preparing = false
    private var levelEmissionCounter = 0

    init(emit: @escaping @Sendable (FluidAudioEvent) -> Void) {
        self.emit = emit
    }

    func prepare() async throws {
        guard !prepared, !preparing else { return }
        preparing = true
        defer { preparing = false }

        emit(.loading("Captions live · preparing speaker labels…", nil))
        var config = SortformerConfig.fastV2_1
        config.precision = .palettized
        #if targetEnvironment(simulator)
        let computeUnits: MLComputeUnits = .cpuAndGPU
        #else
        let computeUnits: MLComputeUnits = .cpuAndNeuralEngine
        #endif
        let models = try await SortformerModels.loadFromHuggingFace(
            config: config,
            computeUnits: computeUnits,
            progressHandler: { [emit] progress in
                emit(.loading("Captions live · preparing speaker labels…", progress.fractionCompleted))
            }
        )
        let diarizer = SortformerDiarizer(config: config, timelineConfig: .sortformerDefault)
        diarizer.initialize(models: models)
        self.diarizer = diarizer
        prepared = true
        emit(.diarizationReady)
    }

    func consume(buffer: sending AVAudioPCMBuffer) {
        do {
            let samples = try converter.resampleBuffer(buffer)
            levelEmissionCounter += 1
            if levelEmissionCounter >= 4 {
                levelEmissionCounter = 0
                emit(.audioLevel(Self.normalizedLevel(for: samples)))
            }

            guard prepared,
                  let update = try diarizer?.process(samples: samples),
                  let segment = (update.tentativeSegments.last ?? update.finalizedSegments.last) else {
                return
            }
            emit(.speaker(segment.speakerIndex))
        } catch {
            emit(.diarizationFailure("Speaker separation paused: \(error.localizedDescription)"))
        }
    }

    func resetSession() {
        levelEmissionCounter = 0
        diarizer?.reset()
        emit(.audioLevel(0))
    }

    private static func normalizedLevel(for samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(Float.zero) { partial, sample in
            partial + sample * sample
        } / Float(samples.count)
        let decibels = 20 * log10(max(sqrt(meanSquare), 0.000_001))
        return min(max((decibels + 60) / 60, 0), 1)
    }
}

/// AVAudioEngine's tap is serial, but finishing/deleting a session happens on
/// MainActor. A small lock keeps AVAudioFile ownership deterministic.
private final class SessionAudioRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private(set) var url: URL?

    func begin(format: AVAudioFormat) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        if let file, let url {
            _ = file
            return url
        }

        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("mochi-\(UUID().uuidString).caf")
        self.file = try AVAudioFile(forWriting: url, settings: format.settings)
        self.url = url
        return url
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        try? file?.write(from: buffer)
    }

    func finish() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        return url
    }

    func discard() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        if let url { try? FileManager.default.removeItem(at: url) }
        url = nil
    }

    func releaseWithoutDeleting() {
        lock.lock()
        defer { lock.unlock() }
        file = nil
        url = nil
    }
}

@MainActor
final class SpeechRecognitionService: ObservableObject {
    private static let logger = Logger(subsystem: "com.jamesangrellera.mochi", category: "Speech")

    enum ServiceError: LocalizedError {
        case microphoneDenied
        case headphonesRequired
        case noFeaturesEnabled

        var errorDescription: String? {
            switch self {
            case .microphoneDenied:
                "Microphone access is off. Enable it in Settings or try guided demo."
            case .headphonesRequired:
                "Voice Lift needs wired, USB, or Bluetooth headphones. Connect them and try again."
            case .noFeaturesEnabled:
                "Turn on captions, Voice Lift, or both before starting."
            }
        }
    }

    @Published private(set) var partialText = ""
    @Published private(set) var partialSpeakerIndex = 0
    @Published private(set) var microphoneLevel: Float = 0
    @Published private(set) var isReceivingAudio = false
    @Published private(set) var isListening = false
    @Published private(set) var isPreparing = false
    @Published private(set) var isCaptionModelDownloaded = false
    @Published private(set) var isCaptioningReady = false
    @Published private(set) var isDiarizationReady = false
    @Published private(set) var preparationProgress: Double?
    @Published private(set) var statusMessage = "Ready to caption"
    @Published private(set) var errorMessage: String?
    @Published private(set) var recordingURL: URL?
    @Published var captionEngine: CaptionEngine = .openAIRealtime
    @Published var captionsEnabled = true
    @Published var voiceLiftEnabled = false
    @Published var voiceLiftGainDB = 6.0
    @Published private(set) var voiceLiftRouteName: String?
    @Published private(set) var activeCaptionEngine: CaptionEngine?

    var onUtterance: ((RecognizedUtterance) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let voiceEQ = AVAudioUnitEQ(numberOfBands: 2)
    private let voiceLimiter: AVAudioUnitEffect = {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: description)
    }()
    private let recorder = SessionAudioRecorder()
    private var isInputTapInstalled = false
    private var isStarting = false
    private var captionPreparationTask: Task<Void, Never>?
    private var diarizationPreparationTask: Task<Void, Never>?
    private var voiceLiftConnected = false

    private lazy var diarization = DiarizationPipeline { [weak self] event in
        Task { @MainActor [weak self] in self?.handle(event) }
    }
    private lazy var transcriber = WhisperKitCaptionTranscriber { [weak self] event in
        Task { @MainActor [weak self] in self?.handle(event) }
    }
    private lazy var realtimeTranscriber = OpenAIRealtimeTranscriber { [weak self] event in
        Task { @MainActor [weak self] in self?.handle(event) }
    }

    init() {
        let lowCut = voiceEQ.bands[0]
        lowCut.filterType = .highPass
        lowCut.frequency = 120
        lowCut.bypass = false

        let speechPresence = voiceEQ.bands[1]
        speechPresence.filterType = .parametric
        speechPresence.frequency = 2_600
        speechPresence.bandwidth = 1.15
        speechPresence.gain = 3
        speechPresence.bypass = false

        AudioUnitSetParameter(voiceLimiter.audioUnit, kDynamicsProcessorParam_Threshold, kAudioUnitScope_Global, 0, -10, 0)
        AudioUnitSetParameter(voiceLimiter.audioUnit, kDynamicsProcessorParam_HeadRoom, kAudioUnitScope_Global, 0, 4, 0)
        AudioUnitSetParameter(voiceLimiter.audioUnit, kDynamicsProcessorParam_AttackTime, kAudioUnitScope_Global, 0, 0.001, 0)
        AudioUnitSetParameter(voiceLimiter.audioUnit, kDynamicsProcessorParam_ReleaseTime, kAudioUnitScope_Global, 0, 0.06, 0)

        audioEngine.attach(voiceEQ)
        audioEngine.attach(voiceLimiter)
    }

    func requestPermissions() async throws {
        let microphoneGranted = await AVAudioApplication.requestRecordPermission()
        guard microphoneGranted else { throw ServiceError.microphoneDenied }
    }

    /// Downloads and loads Whisper before any recording can begin. On later
    /// launches WhisperKit reuses its on-device cache and only reloads Core ML.
    func prepareCaptionModel() async {
        if isCaptioningReady {
            await prepareDiarizationModel()
            return
        }
        if let captionPreparationTask {
            await captionPreparationTask.value
            return
        }

        isPreparing = true
        preparationProgress = nil
        errorMessage = nil
        statusMessage = "Preparing on-device hearing…"
        Self.logger.info("Whisper preparation requested")

        let transcriber = transcriber
        let task = Task {
            do {
                try await transcriber.prepare()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // The transcriber also emits readiness events, but those are
                    // delivered on an independent MainActor task. Set the state
                    // synchronously here so an immediately-following start can
                    // never observe a stale false value.
                    self.isCaptionModelDownloaded = true
                    self.isCaptioningReady = true
                    if self.errorMessage == nil {
                        self.statusMessage = "On-device multilingual Whisper ready"
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.statusMessage = "Hearing model setup failed"
                    Self.logger.error("Whisper preparation failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        captionPreparationTask = task
        await task.value
        captionPreparationTask = nil
        isPreparing = false
        Self.logger.info("Whisper preparation task finished; ready=\(self.isCaptioningReady)")
        await prepareDiarizationModel()
    }

    /// FluidAudio owns speaker labels for both caption engines. Preparing it
    /// alongside Whisper prevents a recording from beginning while Sortformer
    /// is still downloading or compiling and silently assigning Speaker 1.
    func prepareDiarizationModel() async {
        guard !isDiarizationReady else { return }
        if let diarizationPreparationTask {
            await diarizationPreparationTask.value
            return
        }

        let diarization = diarization
        let task = Task {
            do {
                try await diarization.prepare()
            } catch {
                await MainActor.run { [weak self] in
                    self?.statusMessage = "Speaker labels unavailable"
                    Self.logger.error("Speaker separation unavailable: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        diarizationPreparationTask = task
        await task.value
        diarizationPreparationTask = nil
    }

    func start() async {
        guard !isStarting, !isListening else { return }
        guard captionsEnabled || voiceLiftEnabled else {
            errorMessage = ServiceError.noFeaturesEnabled.localizedDescription
            statusMessage = "Choose a listening feature"
            return
        }
        // Realtime does not depend on Whisper being loadable. Keeping this
        // requirement conditional is important on Simulator, where Core ML
        // can occasionally reject an otherwise complete Whisper model.
        guard !captionsEnabled || captionEngine != .onDeviceWhisper || isCaptioningReady else {
            errorMessage = "Finish the on-device hearing model setup before starting."
            statusMessage = "Hearing model is not ready"
            return
        }
        isStarting = true
        preparationProgress = nil
        errorMessage = nil
        statusMessage = "Starting microphone…"

        do {
            try await requestPermissions()
            var realtimeFallback = false
            if captionsEnabled, captionEngine == .openAIRealtime {
                activeCaptionEngine = .openAIRealtime
                statusMessage = "Connecting to OpenAI Realtime…"
                do {
                    let clientSecret = try await MochiAPI.shared.createRealtimeClientSecret()
                    try await realtimeTranscriber.connect(clientSecret: clientSecret)
                } catch {
                    await realtimeTranscriber.cancel()
                    if isCaptioningReady {
                        realtimeFallback = true
                        activeCaptionEngine = .onDeviceWhisper
                        Self.logger.error("Realtime setup failed; using Whisper: \(error.localizedDescription, privacy: .public)")
                    } else {
                        // Do not pretend a local fallback is live when its
                        // model failed to load. Surface the Realtime failure.
                        throw error
                    }
                }
            } else if captionsEnabled {
                activeCaptionEngine = .onDeviceWhisper
            } else {
                activeCaptionEngine = nil
            }

            // Sortformer supplies speaker identity regardless of whether text
            // comes from OpenAI Realtime or WhisperKit. Its models are cached
            // after onboarding, so this is normally only an initialization.
            if captionsEnabled { await prepareDiarizationModel() }
            try beginCapture()
            isListening = true
            isPreparing = false
            if !captionsEnabled, voiceLiftEnabled {
                statusMessage = "Voice Lift is active through \(voiceLiftRouteName ?? "headphones")"
                Self.logger.info("Voice Lift listening assistance started")
            } else if realtimeFallback {
                statusMessage = "Realtime unavailable · using on-device Whisper"
            } else if activeCaptionEngine == .openAIRealtime {
                statusMessage = "OpenAI Realtime captions are live"
                Self.logger.info("Audio recording and OpenAI Realtime transcription started")
            } else {
                statusMessage = "On-device Whisper captions are live"
                Self.logger.info("Audio recording and on-device Whisper transcription started")
            }

        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Listening unavailable"
            Self.logger.error("Listening start failed: \(error.localizedDescription, privacy: .public)")
            stopCapture()
            await realtimeTranscriber.cancel()
            await transcriber.finish()
            activeCaptionEngine = nil
        }

        isStarting = false
    }

    /// Pauses capture while keeping the same recording file available for resume.
    func stop() {
        stopCapture()
        partialText = ""
        microphoneLevel = 0
        isReceivingAudio = false
        isListening = false
        statusMessage = "Capture paused"
        let engine = activeCaptionEngine
        activeCaptionEngine = nil
        Task {
            if engine == .openAIRealtime {
                await realtimeTranscriber.finish()
            } else if engine == .onDeviceWhisper {
                await transcriber.finish()
            }
        }
    }

    func finishSession() async -> URL? {
        stopCapture()
        isListening = false
        statusMessage = "Finishing transcript…"
        let engine = activeCaptionEngine
        if engine == .openAIRealtime {
            await realtimeTranscriber.finish()
        } else if engine == .onDeviceWhisper {
            await transcriber.finish()
        }
        activeCaptionEngine = nil
        let url = recorder.finish()
        recordingURL = url
        partialText = ""
        microphoneLevel = 0
        statusMessage = "Recording and transcript ready"
        return url
    }

    func discardSession() {
        stopCapture()
        recorder.discard()
        recordingURL = nil
        partialText = ""
        microphoneLevel = 0
        isReceivingAudio = false
        isListening = false
        Task {
            await realtimeTranscriber.cancel()
            await transcriber.resetSession()
            await diarization.resetSession()
        }
        activeCaptionEngine = nil
    }

    /// Detaches a completed recorder after its metadata has been safely archived.
    /// The CAF file remains available to the recordings library.
    func releaseArchivedSession() {
        stopCapture()
        recorder.releaseWithoutDeleting()
        recordingURL = nil
    }

    private func beginCapture() throws {
        stopCapture()

        let session = AVAudioSession.sharedInstance()
        if voiceLiftEnabled {
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .allowBluetoothA2DP]
            )
        } else {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        }
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        if voiceLiftEnabled {
            guard let route = Self.externalListeningRoute(in: session.currentRoute) else {
                throw ServiceError.headphonesRequired
            }
            voiceLiftRouteName = route.portName
        } else {
            voiceLiftRouteName = nil
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        if voiceLiftEnabled {
            voiceEQ.globalGain = Float(min(max(voiceLiftGainDB, 3), 9))
            audioEngine.connect(input, to: voiceEQ, format: format)
            audioEngine.connect(voiceEQ, to: voiceLimiter, format: format)
            audioEngine.connect(voiceLimiter, to: audioEngine.mainMixerNode, format: nil)
            voiceLiftConnected = true
        }
        recordingURL = try recorder.begin(format: format)
        let recorder = recorder
        let diarization = diarization
        let transcriber = transcriber
        let realtimeTranscriber = realtimeTranscriber
        let engine = activeCaptionEngine
        let captionsEnabled = captionsEnabled

        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { @Sendable buffer, _ in
            recorder.write(buffer)
            guard let diarizationBuffer = Self.copy(buffer) else { return }
            Task { await diarization.consume(buffer: diarizationBuffer) }
            guard captionsEnabled,
                  let transcriptionBuffer = Self.copy(buffer) else { return }
            if engine == .openAIRealtime {
                Task { await realtimeTranscriber.consume(buffer: transcriptionBuffer) }
            } else if engine == .onDeviceWhisper {
                Task { await transcriber.consume(buffer: transcriptionBuffer) }
            }
        }
        isInputTapInstalled = true

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopCapture()
            throw error
        }
    }

    private func stopCapture() {
        audioEngine.stop()
        if isInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isInputTapInstalled = false
        }
        if voiceLiftConnected {
            audioEngine.disconnectNodeOutput(audioEngine.inputNode)
            audioEngine.disconnectNodeOutput(voiceEQ)
            audioEngine.disconnectNodeOutput(voiceLimiter)
            voiceLiftConnected = false
        }
        voiceLiftRouteName = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func externalListeningRoute(in route: AVAudioSessionRouteDescription) -> AVAudioSessionPortDescription? {
        let supported: Set<AVAudioSession.Port> = [
            .headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP,
            .usbAudio, .lineOut
        ]
        return route.outputs.first { supported.contains($0.portType) }
    }

    private func handle(_ event: FluidAudioEvent) {
        switch event {
        case .loading(let message, let progress):
            if errorMessage == nil {
                statusMessage = message
            }
            preparationProgress = progress
        case .captionModelDownloaded:
            isCaptionModelDownloaded = true
            preparationProgress = 1
            if errorMessage == nil {
                statusMessage = "Whisper downloaded · optimizing for this device…"
            }
        case .captioningReady:
            isCaptioningReady = true
            if errorMessage == nil {
                statusMessage = "On-device Whisper captions ready"
            }
            Self.logger.info("WhisperKit caption model is ready")
        case .realtimeReady:
            if errorMessage == nil {
                statusMessage = "OpenAI Realtime connected"
            }
            Self.logger.info("OpenAI Realtime transcription is ready")
        case .diarizationReady:
            isDiarizationReady = true
            if errorMessage == nil {
                statusMessage = isListening
                    ? "\(activeCaptionEngine?.shortTitle ?? "Captions") live · speaker separation ready"
                    : "Speaker separation ready"
            }
            preparationProgress = 1
            Self.logger.info("Sortformer speaker separation is ready")
        case .audioLevel(let level):
            microphoneLevel = level
            isReceivingAudio = true
        case .partial(let text):
            partialText = text
        case .speaker(let index):
            partialSpeakerIndex = index
            Task {
                await transcriber.updateSpeaker(index)
                await realtimeTranscriber.updateSpeaker(index)
            }
        case .utterance(let utterance):
            onUtterance?(utterance)
        case .captionFailure(let message):
            errorMessage = message
            statusMessage = message
            Self.logger.error("\(message, privacy: .public)")
        case .realtimeFailure(let message):
            errorMessage = message
            statusMessage = "Realtime captions interrupted"
            Self.logger.error("\(message, privacy: .public)")
        case .diarizationFailure(let message):
            statusMessage = "Captions live · speaker labels unavailable"
            Self.logger.error("\(message, privacy: .public)")
        }
    }

    /// AVAudioEngine reuses tap buffers immediately after the callback returns.
    nonisolated private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let destination = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else { return nil }

        destination.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)
        guard sourceBuffers.count == destinationBuffers.count else { return nil }

        for index in sourceBuffers.indices {
            let sourceBuffer = sourceBuffers[index]
            guard let sourceData = sourceBuffer.mData,
                  let destinationData = destinationBuffers[index].mData else { return nil }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
            destinationBuffers[index].mDataByteSize = sourceBuffer.mDataByteSize
        }
        return destination
    }
}
