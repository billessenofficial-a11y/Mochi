import XCTest
@testable import ClearCue

@MainActor
final class ConversationStoreTests: XCTestCase {
    func testRepairKeepsOriginalEvidenceAndCreatesSeparateAnnotation() {
        let store = ConversationStore()
        let event = ConversationStore.demoBeats.compactMap(\.event).first { $0.type == .importantAmbiguity }!
        let originalQuote = event.sourceQuote

        store.activeEvent = event
        store.resolveActiveEvent(with: "5:50 PM")

        XCTAssertEqual(event.sourceQuote, originalQuote)
        XCTAssertEqual(store.repairs.count, 1)
        XCTAssertEqual(store.repairs.first?.resolvedValue, "5:50 PM")
        XCTAssertEqual(store.repairs.first?.sourceSegmentIDs, event.sourceSegmentIDs)
        XCTAssertTrue(store.repairs.first?.userConfirmed == true)
    }

    func testCatchUpNeverReturnsMoreThanFourItems() {
        let store = ConversationStore()
        XCTAssertLessThanOrEqual(store.currentCatchUp.count, 4)
    }

    func testListeningAssistancePassesIndependentFeatureChoicesToCapture() {
        let store = ConversationStore()

        store.begin(.live, captionsEnabled: false, voiceLiftEnabled: true)

        XCTAssertFalse(store.sessionCaptionsEnabled)
        XCTAssertTrue(store.sessionVoiceLiftEnabled)
        XCTAssertFalse(store.speechService.captionsEnabled)
        XCTAssertTrue(store.speechService.voiceLiftEnabled)
    }

    func testHomeStyleSessionRemainsCaptionsOnly() {
        let store = ConversationStore()

        store.begin(.live)

        XCTAssertTrue(store.sessionCaptionsEnabled)
        XCTAssertFalse(store.sessionVoiceLiftEnabled)
    }
}
