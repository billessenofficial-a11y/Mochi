import XCTest
@testable import Mochi

final class WatchConnectivityTests: XCTestCase {
    func testWatchSnapshotUsesAPropertyListSafeGroundedPayload() throws {
        let segment = TranscriptSegment(
            id: "segment-1",
            speaker: .maya,
            startSeconds: 12,
            text: "James, can you bring the blue folder?",
            isFinal: true,
            emphasis: .nameMention
        )
        let mention = AttentionEvent(
            id: "mention-1",
            type: .nameMention,
            sourceSegmentIDs: [segment.id],
            title: "Maya mentioned you",
            explanation: "You may need to respond.",
            sourceQuote: segment.text,
            detailType: "name",
            candidates: [],
            clarificationPrompt: "Could you say that again?",
            state: .new
        )
        let catchUp = CatchUpItem(
            id: "catch-up-1",
            kind: .needsYou,
            title: "Bring blue folder",
            text: "Maya asked you to bring the blue folder.",
            sourceSegmentIDs: [segment.id]
        )

        let payload = PhoneWatchSnapshot(
            sessionState: "listening",
            elapsedSeconds: 12,
            consentRequired: false,
            latestSegment: segment,
            nameMention: mention,
            catchUpOverview: "One request is directed to you.",
            catchUpItems: [catchUp]
        ).payload

        XCTAssertEqual(payload["mentionID"] as? String, mention.id)
        XCTAssertEqual(payload["latestText"] as? String, segment.text)
        XCTAssertEqual((payload["catchUpItems"] as? [[String: String]])?.first?["id"], catchUp.id)
        XCTAssertNoThrow(
            try PropertyListSerialization.data(
                fromPropertyList: payload,
                format: .binary,
                options: 0
            )
        )
    }
}
