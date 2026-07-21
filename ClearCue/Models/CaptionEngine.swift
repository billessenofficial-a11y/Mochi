import Foundation

enum CaptionEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case openAIRealtime
    case onDeviceWhisper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openAIRealtime:
            "OpenAI Realtime"
        case .onDeviceWhisper:
            "On-device Whisper"
        }
    }

    var shortTitle: String {
        switch self {
        case .openAIRealtime:
            "Realtime"
        case .onDeviceWhisper:
            "Whisper"
        }
    }

    var detail: String {
        switch self {
        case .openAIRealtime:
            "Lowest-latency multilingual captions. Session audio is sent to OpenAI."
        case .onDeviceWhisper:
            "Private multilingual captions using the model downloaded during setup."
        }
    }

    var recapLabel: String {
        switch self {
        case .openAIRealtime:
            "OpenAI Realtime · multilingual"
        case .onDeviceWhisper:
            "On-device Whisper · multilingual"
        }
    }

    var systemImage: String {
        switch self {
        case .openAIRealtime:
            "bolt.horizontal.circle.fill"
        case .onDeviceWhisper:
            "iphone.gen3.circle.fill"
        }
    }
}
