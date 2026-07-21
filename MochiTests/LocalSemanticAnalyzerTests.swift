import XCTest
@testable import Mochi

final class LocalSemanticAnalyzerTests: XCTestCase {
    func testNicknameMentionCreatesPersonalCue() {
        let segment = TranscriptSegment(
            id: "nickname",
            speaker: .live(index: 0),
            startSeconds: 1,
            text: "Hey Jimmy, did you catch that?",
            isFinal: true
        )

        let events = LocalSemanticAnalyzer().analyze(
            segment: segment,
            userName: "James",
            aliases: ["Jimmy", "Jim"]
        )

        XCTAssertTrue(events.contains(where: { $0.type == .nameMention }))
    }

    private let analyzer = LocalSemanticAnalyzer()

    func testNameMentionAndQuestionAreGroundedInSourceSegment() {
        let segment = TranscriptSegment(
            id: "seg-1",
            speaker: .maya,
            startSeconds: 4,
            text: "James, can you bring the blue folder?",
            isFinal: true
        )

        let events = analyzer.analyze(segment: segment, userName: "James")

        XCTAssertEqual(Set(events.map(\.type)), Set([.nameMention, .directQuestion]))
        XCTAssertTrue(events.allSatisfy { $0.sourceSegmentIDs == ["seg-1"] })
        XCTAssertTrue(events.allSatisfy { $0.sourceQuote == segment.text })
    }

    func testPartialCaptionsNeverGenerateAttentionEvents() {
        let segment = TranscriptSegment(
            id: "partial",
            speaker: .unknown,
            startSeconds: 0,
            text: "James, is it five fifty?",
            isFinal: false
        )

        XCTAssertTrue(analyzer.analyze(segment: segment, userName: "James").isEmpty)
    }

    func testClearTimeIsImportantButNotInventedAsAmbiguity() {
        let segment = TranscriptSegment(
            id: "seg-time",
            speaker: .maya,
            startSeconds: 12,
            text: "Let's meet at 5:50 PM.",
            isFinal: true
        )

        let events = analyzer.analyze(segment: segment, userName: "James")

        XCTAssertEqual(events.map(\.type), [.criticalDetail])
        XCTAssertEqual(events.first?.candidates, [])
        XCTAssertEqual(events.first?.clarificationPrompt, "Could you repeat that detail, please?")
    }
}
