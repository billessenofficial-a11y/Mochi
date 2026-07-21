import Foundation

enum AppRoute: Equatable {
    case home
    case conversation
    case recap
}

enum AppTab: Hashable {
    case home
    case recordings
    case settings
}

enum ConversationMode: String, Codable, Equatable {
    case live
    case recording
    case guidedDemo

    var title: String {
        switch self {
        case .live: "Start hearing"
        case .recording: "Start recording"
        case .guidedDemo: "Guided demo"
        }
    }

    var capturesAudio: Bool { self != .guidedDemo }
}

enum ConversationStatus: Equatable {
    case ready
    case listening
    case paused
    case finishing
}

struct Speaker: Identifiable, Hashable, Codable {
    let id: String
    var displayName: String
    var style: SpeakerStyle

    static let maya = Speaker(id: "maya", displayName: "Maya", style: .mint)
    static let leo = Speaker(id: "leo", displayName: "Leo", style: .blue)
    static let user = Speaker(id: "user", displayName: "You", style: .lilac)
    static let unknown = Speaker(id: "unknown", displayName: "Speaker", style: .neutral)

    static func live(index: Int) -> Speaker {
        let normalizedIndex = max(0, index)
        let styles: [SpeakerStyle] = [.mint, .blue, .lilac, .neutral]
        return Speaker(
            id: "speaker-\(normalizedIndex + 1)",
            displayName: "Speaker \(normalizedIndex + 1)",
            style: styles[normalizedIndex % styles.count]
        )
    }
}

enum SpeakerStyle: String, Hashable, Codable {
    case mint
    case blue
    case lilac
    case neutral
}

struct TranscriptSegment: Identifiable, Hashable, Codable {
    let id: String
    let speaker: Speaker
    let startSeconds: TimeInterval
    var text: String
    var isFinal: Bool
    var emphasis: SegmentEmphasis?

    var timestamp: String {
        let total = max(0, Int(startSeconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum SegmentEmphasis: String, Hashable, Codable {
    case nameMention
    case question
    case importantDetail
}

enum AttentionType: String, Hashable, Codable {
    case nameMention
    case directQuestion
    case criticalDetail
    case importantAmbiguity
    case overlapOrMissedContext
    case decision
    case actionAssignment
}

enum AttentionState: String, Hashable, Codable {
    case new
    case dismissed
    case repairing
    case resolved
    case unresolved
}

struct AttentionEvent: Identifiable, Hashable, Codable {
    let id: String
    let type: AttentionType
    let sourceSegmentIDs: [String]
    let title: String
    let explanation: String
    let sourceQuote: String
    let detailType: String?
    let candidates: [String]
    var clarificationPrompt: String
    var state: AttentionState
}

struct RepairAnnotation: Identifiable, Hashable, Codable {
    let id: String
    let eventID: String
    let sourceSegmentIDs: [String]
    let resolvedValue: String?
    let createdAt: Date
    let userConfirmed: Bool
}

enum RecapStatus: String, Hashable, Codable {
    case confirmed
    case heard
    case unresolved

    var label: String { rawValue.capitalized }
}

enum RecapKind: String, Hashable, Codable {
    case decision
    case action
    case detail
    case unresolved
}

struct RecapItem: Identifiable, Hashable, Codable {
    let id: String
    let kind: RecapKind
    let text: String
    let status: RecapStatus
    let owner: String?
    let sourceSegmentIDs: [String]
    let confirmationID: String?
}

struct SavedConversation: Identifiable, Hashable, Codable {
    let id: String
    let createdAt: Date
    let title: String
    let durationSeconds: Int
    let recordingFileName: String
    let segments: [TranscriptSegment]
    let events: [AttentionEvent]
    let repairs: [RepairAnnotation]
    let recapItems: [RecapItem]
    let recapErrorMessage: String?
    let captionEngine: CaptionEngine?
    /// The low-latency transcript retained as an audit trail when a completed
    /// recording receives a more accurate speaker-aware cloud pass.
    let provisionalSegments: [TranscriptSegment]?
    let transcriptRefinedAt: Date?
    let transcriptRefinementErrorMessage: String?

    init(
        id: String,
        createdAt: Date,
        title: String,
        durationSeconds: Int,
        recordingFileName: String,
        segments: [TranscriptSegment],
        events: [AttentionEvent],
        repairs: [RepairAnnotation],
        recapItems: [RecapItem],
        recapErrorMessage: String?,
        captionEngine: CaptionEngine? = nil,
        provisionalSegments: [TranscriptSegment]? = nil,
        transcriptRefinedAt: Date? = nil,
        transcriptRefinementErrorMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.durationSeconds = durationSeconds
        self.recordingFileName = recordingFileName
        self.segments = segments
        self.events = events
        self.repairs = repairs
        self.recapItems = recapItems
        self.recapErrorMessage = recapErrorMessage
        self.captionEngine = captionEngine
        self.provisionalSegments = provisionalSegments
        self.transcriptRefinedAt = transcriptRefinedAt
        self.transcriptRefinementErrorMessage = transcriptRefinementErrorMessage
    }

    var captionCount: Int { segments.count }
    var confirmedRepairCount: Int { repairs.filter(\.userConfirmed).count }

    var formattedDuration: String {
        let total = max(0, durationSeconds)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

enum CatchUpKind: String, Hashable, Codable {
    case needsYou
    case decision
    case action
    case detail
    case recent
}

struct CatchUpItem: Identifiable, Hashable {
    let id: String
    let kind: CatchUpKind
    let title: String
    let text: String
    let sourceSegmentIDs: [String]
}

struct GuidedDemoBeat {
    let delayNanoseconds: UInt64
    let segment: TranscriptSegment
    let event: AttentionEvent?
}
