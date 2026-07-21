@preconcurrency import AVFoundation
@preconcurrency import FluidAudio
import Foundation

/// Streams 24 kHz mono PCM16 audio to a transcription-only OpenAI Realtime
/// session. The permanent API key stays on Mochi's backend; this actor receives
/// only a short-lived client secret.
actor OpenAIRealtimeTranscriber {
    enum RealtimeError: LocalizedError {
        case invalidEndpoint
        case invalidHandshake
        case connectionTimedOut
        case notConnected

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                "The OpenAI Realtime endpoint is unavailable."
            case .invalidHandshake:
                "OpenAI Realtime did not open a transcription session."
            case .connectionTimedOut:
                "OpenAI Realtime took too long to connect."
            case .notConnected:
                "OpenAI Realtime is not connected."
            }
        }
    }

    private struct ServerEvent: Decodable {
        struct ServerError: Decodable {
            let message: String?
        }

        let type: String
        let itemID: String?
        let delta: String?
        let transcript: String?
        let error: ServerError?

        enum CodingKeys: String, CodingKey {
            case type, delta, transcript, error
            case itemID = "item_id"
        }
    }

    private struct ItemState {
        var text: String
        let startSeconds: TimeInterval
        let speakerIndex: Int
    }

    private let emit: @Sendable (FluidAudioEvent) -> Void
    private let converter = AudioConverter(sampleRate: 24_000)
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var isClosing = false

    private var pendingSendSamples: [Float] = []
    private var bufferedAudioSamples = 0
    private var sampleClock = 0
    private var trailingSilenceSamples = 0
    private var speechSeen = false
    private var currentSpeakerIndex = 0
    private var committedItems = 0
    private var completedItems = 0
    private var pendingStarts: [TimeInterval] = []
    private var pendingSpeakers: [Int] = []
    private var items: [String: ItemState] = [:]
    private var latestPartialItemID: String?

    private let sampleRate = 24_000
    private let sendChunkSamples = 2_400
    private let minimumCommitSamples = 12_000
    private let silenceCommitSamples = 12_000
    private let maximumCommitSamples = 96_000
    private let maximumIdleSamples = 24_000
    private let speechThreshold: Float = 0.009

    init(emit: @escaping @Sendable (FluidAudioEvent) -> Void) {
        self.emit = emit
    }

    func connect(clientSecret: RealtimeClientSecret) async throws {
        await cancel()
        // The ephemeral secret is already bound to a transcription session and
        // its model. Passing `model` again makes Realtime reject the handshake.
        guard let url = URL(string: "wss://api.openai.com/v1/realtime") else {
            throw RealtimeError.invalidEndpoint
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(clientSecret.value)", forHTTPHeaderField: "Authorization")
        // The backend already bound a stable safety identifier when it minted
        // this ephemeral secret. Supplying a different one here is rejected as
        // a conflicting identifier.

        let socket = URLSession.shared.webSocketTask(with: request)
        self.socket = socket
        isClosing = false
        resetState()
        socket.resume()

        let firstMessage = try await firstMessage(from: socket)
        guard try handle(firstMessage, requireSessionEvent: true) else {
            socket.cancel(with: .protocolError, reason: nil)
            self.socket = nil
            throw RealtimeError.invalidHandshake
        }

        try await send([
            "type": "session.update",
            "session": [
                "type": "transcription",
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": sampleRate
                        ],
                        "transcription": [
                            "model": "gpt-realtime-whisper",
                            "delay": "low"
                        ],
                        "turn_detection": NSNull()
                    ]
                ]
            ]
        ])

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
        emit(.realtimeReady)
    }

    func consume(buffer: sending AVAudioPCMBuffer) async {
        guard socket != nil, !isClosing else { return }
        do {
            let samples = try converter.resampleBuffer(buffer)
            guard !samples.isEmpty else { return }

            sampleClock += samples.count
            bufferedAudioSamples += samples.count
            pendingSendSamples.append(contentsOf: samples)

            let rms = Self.rootMeanSquare(samples)
            if rms >= speechThreshold {
                speechSeen = true
                trailingSilenceSamples = 0
            } else if speechSeen {
                trailingSilenceSamples += samples.count
            }

            if pendingSendSamples.count >= sendChunkSamples {
                try await flushPendingAudio()
            }

            // Manual-commit transcription sessions do not have server VAD to
            // discard idle audio. Trim sustained silence so a quiet room cannot
            // grow one unbounded server buffer or skew the next utterance time.
            if !speechSeen, bufferedAudioSamples >= maximumIdleSamples {
                try await send(["type": "input_audio_buffer.clear"])
                bufferedAudioSamples = 0
            }

            let reachedSilenceBoundary = speechSeen &&
                bufferedAudioSamples >= minimumCommitSamples &&
                trailingSilenceSamples >= silenceCommitSamples
            let reachedMaximumDuration = speechSeen && bufferedAudioSamples >= maximumCommitSamples
            if reachedSilenceBoundary || reachedMaximumDuration {
                try await commitCurrentBuffer()
            }
        } catch {
            emit(.realtimeFailure("Realtime captions paused: \(error.localizedDescription)"))
        }
    }

    func updateSpeaker(_ index: Int) {
        currentSpeakerIndex = max(0, index)
    }

    func finish() async {
        guard socket != nil else {
            emit(.partial(""))
            return
        }
        isClosing = true

        do {
            if speechSeen {
                try await commitCurrentBuffer()
            } else {
                try await flushPendingAudio()
            }

            let deadline = ContinuousClock.now + .seconds(4)
            while completedItems < committedItems, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(80))
            }
        } catch {
            // The local recording still completes even if the network closes.
        }

        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        resetState()
        emit(.partial(""))
    }

    func cancel() async {
        isClosing = true
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        resetState()
        emit(.partial(""))
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket {
            do {
                let message = try await socket.receive()
                _ = try handle(message)
            } catch {
                if !isClosing {
                    emit(.realtimeFailure("Realtime connection ended: \(error.localizedDescription)"))
                }
                self.socket = nil
                return
            }
        }
    }

    private func firstMessage(
        from socket: URLSessionWebSocketTask
    ) async throws -> URLSessionWebSocketTask.Message {
        try await withThrowingTaskGroup(of: URLSessionWebSocketTask.Message.self) { group in
            group.addTask {
                try await socket.receive()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(12))
                throw RealtimeError.connectionTimedOut
            }
            guard let message = try await group.next() else {
                throw RealtimeError.invalidHandshake
            }
            group.cancelAll()
            return message
        }
    }

    @discardableResult
    private func handle(
        _ message: URLSessionWebSocketTask.Message,
        requireSessionEvent: Bool = false
    ) throws -> Bool {
        let data: Data
        switch message {
        case .data(let value):
            data = value
        case .string(let value):
            data = Data(value.utf8)
        @unknown default:
            return false
        }

        let event = try JSONDecoder().decode(ServerEvent.self, from: data)
        if requireSessionEvent {
            return event.type == "session.created" || event.type == "transcription_session.created"
        }

        switch event.type {
        case "conversation.item.input_audio_transcription.delta":
            guard let itemID = event.itemID, let delta = event.delta, !delta.isEmpty else { break }
            var state = state(for: itemID)
            state.text += delta
            items[itemID] = state
            latestPartialItemID = itemID
            emit(.partial(state.text.trimmingCharacters(in: .whitespacesAndNewlines)))

        case "conversation.item.input_audio_transcription.completed":
            guard let itemID = event.itemID else { break }
            let state = state(for: itemID)
            let finalText = (event.transcript ?? state.text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            completedItems += 1
            items[itemID] = nil
            if latestPartialItemID == itemID {
                latestPartialItemID = nil
                emit(.partial(""))
            }
            if !finalText.isEmpty {
                emit(.utterance(
                    RecognizedUtterance(
                        id: "realtime-\(itemID)",
                        text: finalText,
                        speakerIndex: state.speakerIndex,
                        startSeconds: state.startSeconds,
                        isRevision: false
                    )
                ))
            }

        case "error":
            emit(.realtimeFailure(event.error?.message ?? "OpenAI Realtime returned an error."))

        default:
            break
        }
        return true
    }

    private func state(for itemID: String) -> ItemState {
        if let existing = items[itemID] { return existing }
        let start = pendingStarts.isEmpty
            ? TimeInterval(sampleClock) / TimeInterval(sampleRate)
            : pendingStarts.removeFirst()
        let speaker = pendingSpeakers.isEmpty ? currentSpeakerIndex : pendingSpeakers.removeFirst()
        let state = ItemState(text: "", startSeconds: start, speakerIndex: speaker)
        items[itemID] = state
        return state
    }

    private func commitCurrentBuffer() async throws {
        try await flushPendingAudio()
        guard bufferedAudioSamples > 0, speechSeen else { return }

        let startSample = max(0, sampleClock - bufferedAudioSamples)
        pendingStarts.append(TimeInterval(startSample) / TimeInterval(sampleRate))
        pendingSpeakers.append(currentSpeakerIndex)
        try await send(["type": "input_audio_buffer.commit"])
        committedItems += 1
        bufferedAudioSamples = 0
        trailingSilenceSamples = 0
        speechSeen = false
    }

    private func flushPendingAudio() async throws {
        guard !pendingSendSamples.isEmpty else { return }
        let samples = pendingSendSamples
        pendingSendSamples.removeAll(keepingCapacity: true)
        let audio = Self.pcm16Data(from: samples).base64EncodedString()
        try await send([
            "type": "input_audio_buffer.append",
            "audio": audio
        ])
    }

    private func send(_ event: [String: Any]) async throws {
        guard let socket else { throw RealtimeError.notConnected }
        let data = try JSONSerialization.data(withJSONObject: event)
        guard let text = String(data: data, encoding: .utf8) else {
            throw RealtimeError.invalidHandshake
        }
        try await socket.send(.string(text))
    }

    private func resetState() {
        pendingSendSamples.removeAll(keepingCapacity: false)
        bufferedAudioSamples = 0
        sampleClock = 0
        trailingSilenceSamples = 0
        speechSeen = false
        currentSpeakerIndex = 0
        committedItems = 0
        completedItems = 0
        pendingStarts.removeAll(keepingCapacity: false)
        pendingSpeakers.removeAll(keepingCapacity: false)
        items.removeAll(keepingCapacity: false)
        latestPartialItemID = nil
    }

    private static func rootMeanSquare(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(Float.zero) { $0 + ($1 * $1) } / Float(samples.count))
    }

    private static func pcm16Data(from samples: [Float]) -> Data {
        var values = samples.map { sample -> Int16 in
            let clipped = min(max(sample, -1), 1)
            return Int16((clipped * Float(Int16.max)).rounded()).littleEndian
        }
        return values.withUnsafeMutableBytes { Data($0) }
    }
}
