@preconcurrency import AVFoundation
import Foundation

actor ClearCueAPI {
    enum APIError: LocalizedError {
        case invalidConfiguration
        case invalidResponse
        case server(String)
        case audioExportUnavailable
        case recordingTooLarge

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                "Mochi's API address is missing."
            case .invalidResponse:
                "Mochi received an invalid response from its API."
            case .server(let message):
                message
            case .audioExportUnavailable:
                "Mochi could not prepare this recording for its accuracy pass."
            case .recordingTooLarge:
                "This recording is too large for one accuracy pass."
            }
        }
    }

    static let shared = ClearCueAPI()

    private let session: URLSession
    private let baseURL: URL
    private let directOpenAI: DirectOpenAIClient?

    init(session: URLSession = .shared) {
        self.session = session
        self.directOpenAI = EmbeddedOpenAIKeyProvider.value.map {
            DirectOpenAIClient(apiKey: $0, session: session)
        }

        let argumentURL: String? = {
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-apiBaseURL"), arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }()
        let configuredURL = argumentURL
            ?? Bundle.main.object(forInfoDictionaryKey: "ClearCueAPIBaseURL") as? String
            ?? "http://127.0.0.1:8787"
        self.baseURL = URL(string: configuredURL) ?? URL(string: "http://127.0.0.1:8787")!
    }

    func generateRecap(
        segments: [TranscriptSegment],
        repairs: [RepairAnnotation],
        userName: String,
        durationSeconds: Int
    ) async throws -> GeneratedRecap {
        if let directOpenAI {
            return try await directOpenAI.generateRecap(
                segments: segments,
                repairs: repairs,
                userName: userName,
                durationSeconds: durationSeconds
            )
        }
        let requestSegments = segments.map {
            RecapSegment(
                id: $0.id,
                speaker: $0.speaker.displayName,
                startSeconds: $0.startSeconds,
                text: $0.text
            )
        }
        let requestRepairs = repairs.filter(\.userConfirmed).map {
            RecapRepair(
                sourceSegmentIDs: $0.sourceSegmentIDs,
                resolvedValue: $0.resolvedValue
            )
        }
        let body = RecapRequest(
            userName: userName,
            durationSeconds: durationSeconds,
            segments: requestSegments,
            repairs: requestRepairs
        )
        return try await request(path: "/v1/recap", body: body)
    }

    func askRecording(
        question: String,
        segments: [TranscriptSegment],
        history: [RecordingChatMessage]
    ) async throws -> GeneratedChatAnswer {
        if let directOpenAI {
            return try await directOpenAI.askRecording(
                question: question,
                segments: segments,
                history: history
            )
        }
        let body = RecordingChatRequest(
            question: question,
            segments: segments.map {
                RecapSegment(
                    id: $0.id,
                    speaker: $0.speaker.displayName,
                    startSeconds: $0.startSeconds,
                    text: $0.text
                )
            },
            history: history.suffix(10).map {
                RecordingChatHistoryItem(role: $0.role.rawValue, text: $0.text)
            }
        )
        return try await request(path: "/v1/chat", body: body)
    }

    func generateCatchUp(
        segments: [TranscriptSegment],
        userName: String,
        aliases: [String]
    ) async throws -> GeneratedCatchUp {
        if let directOpenAI {
            return try await directOpenAI.generateCatchUp(
                segments: segments,
                userName: userName,
                aliases: aliases
            )
        }
        let body = CatchUpRequest(
            userName: userName,
            aliases: aliases,
            segments: segments.suffix(20).map {
                RecapSegment(
                    id: $0.id,
                    speaker: $0.speaker.displayName,
                    startSeconds: $0.startSeconds,
                    text: $0.text
                )
            }
        )
        return try await request(path: "/v1/catch-up", body: body, timeoutInterval: 25)
    }

    func createRealtimeClientSecret() async throws -> RealtimeClientSecret {
        if let directOpenAI {
            return try await directOpenAI.createRealtimeClientSecret()
        }
        return try await request(path: "/v1/realtime-token", body: EmptyRequest(), timeoutInterval: 12)
    }

    func refineRecording(at recordingURL: URL) async throws -> GeneratedRefinedTranscript {
        let uploadURL = try await exportForTranscription(recordingURL)
        defer { try? FileManager.default.removeItem(at: uploadURL) }

        let values = try uploadURL.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 25 * 1_024 * 1_024 else {
            throw APIError.recordingTooLarge
        }
        if let directOpenAI {
            return try await directOpenAI.refineRecording(at: uploadURL)
        }
        guard let url = URL(string: "/v1/transcribe-recording", relativeTo: baseURL) else {
            throw APIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        let (data, urlResponse) = try await session.upload(for: request, fromFile: uploadURL)
        return try decodeResponse(data: data, response: urlResponse)
    }

    private func request<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        timeoutInterval: TimeInterval = 60
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw APIError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, urlResponse) = try await session.data(for: request)
        return try decodeResponse(data: data, response: urlResponse)
    }

    private func decodeResponse<Response: Decodable>(
        data: Data,
        response: URLResponse
    ) throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(ServerError.self, from: data)
            throw APIError.server(error?.error ?? "Mochi API returned status \(httpResponse.statusCode).")
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func exportForTranscription(_ recordingURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mochi-refinement-\(UUID().uuidString).m4a")
        let asset = AVURLAsset(url: recordingURL)
        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw APIError.audioExportUnavailable
        }
        do {
            try await exporter.export(to: outputURL, as: .m4a)
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw APIError.audioExportUnavailable
        }
    }
}

struct GeneratedRecap: Codable, Sendable {
    let title: String
    let items: [GeneratedRecapItem]
}

struct GeneratedRecapItem: Codable, Sendable {
    let kind: RecapKind
    let text: String
    let status: RecapStatus
    let owner: String?
    let sourceSegmentIDs: [String]

    enum CodingKeys: String, CodingKey {
        case kind, text, status, owner
        case sourceSegmentIDs = "source_segment_ids"
    }
}

struct GeneratedChatAnswer: Codable, Sendable {
    let answer: String
    let sourceSegmentIDs: [String]

    enum CodingKeys: String, CodingKey {
        case answer
        case sourceSegmentIDs = "source_segment_ids"
    }
}

struct GeneratedCatchUp: Codable, Sendable {
    let overview: String
    let items: [GeneratedCatchUpItem]
}

struct GeneratedCatchUpItem: Codable, Sendable, Identifiable {
    let id: String
    let kind: CatchUpKind
    let title: String
    let text: String
    let sourceSegmentIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id, kind, title, text
        case sourceSegmentIDs = "source_segment_ids"
    }
}

struct RealtimeClientSecret: Decodable, Sendable {
    let value: String
    let expiresAt: Int

    enum CodingKeys: String, CodingKey {
        case value
        case expiresAt = "expires_at"
    }
}

struct GeneratedRefinedTranscript: Decodable, Sendable {
    let durationSeconds: TimeInterval?
    let segments: [GeneratedRefinedSegment]

    enum CodingKeys: String, CodingKey {
        case segments
        case durationSeconds = "duration_seconds"
    }
}

struct GeneratedRefinedSegment: Decodable, Sendable {
    let id: String
    let speaker: String
    let startSeconds: TimeInterval
    let endSeconds: TimeInterval
    let text: String

    enum CodingKeys: String, CodingKey {
        case id, speaker, text
        case startSeconds = "start_seconds"
        case endSeconds = "end_seconds"
    }
}

enum RecordingChatRole: String, Codable, Sendable {
    case user
    case assistant
}

struct RecordingChatMessage: Identifiable, Hashable, Sendable {
    let id: String
    let role: RecordingChatRole
    let text: String
    let sourceSegmentIDs: [String]

    init(id: String = UUID().uuidString, role: RecordingChatRole, text: String, sourceSegmentIDs: [String] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.sourceSegmentIDs = sourceSegmentIDs
    }
}

private struct ServerError: Decodable {
    let error: String
}

private struct EmptyRequest: Encodable {}

private struct RecapRequest: Encodable {
    let userName: String
    let durationSeconds: Int
    let segments: [RecapSegment]
    let repairs: [RecapRepair]

    enum CodingKeys: String, CodingKey {
        case segments, repairs
        case userName = "user_name"
        case durationSeconds = "duration_seconds"
    }
}

private struct RecapSegment: Encodable {
    let id: String
    let speaker: String
    let startSeconds: TimeInterval
    let text: String

    enum CodingKeys: String, CodingKey {
        case id, speaker, text
        case startSeconds = "start_seconds"
    }
}

private struct RecapRepair: Encodable {
    let sourceSegmentIDs: [String]
    let resolvedValue: String?

    enum CodingKeys: String, CodingKey {
        case sourceSegmentIDs = "source_segment_ids"
        case resolvedValue = "resolved_value"
    }
}

private struct RecordingChatRequest: Encodable {
    let question: String
    let segments: [RecapSegment]
    let history: [RecordingChatHistoryItem]
}

private struct CatchUpRequest: Encodable {
    let userName: String
    let aliases: [String]
    let segments: [RecapSegment]

    enum CodingKeys: String, CodingKey {
        case aliases, segments
        case userName = "user_name"
    }
}

private struct RecordingChatHistoryItem: Encodable {
    let role: String
    let text: String
}
