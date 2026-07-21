import Foundation
import XCTest
@testable import Mochi

final class ConversationArchiveTests: XCTestCase {
    private var rootURL: URL!

    override func setUpWithError() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mochi-archive-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: rootURL.path) {
            try FileManager.default.removeItem(at: rootURL)
        }
    }

    func testConversationRoundTripsWithTranscriptAndRecap() throws {
        let archive = ConversationArchive(rootDirectory: rootURL)
        try FileManager.default.createDirectory(at: archive.recordingsDirectory, withIntermediateDirectories: true)
        let audioURL = archive.recordingsDirectory.appendingPathComponent("session.caf")
        try Data([0x43, 0x41, 0x46]).write(to: audioURL)

        let segment = TranscriptSegment(
            id: "segment-1",
            speaker: .live(index: 0),
            startSeconds: 2,
            text: "Please bring the blue folder.",
            isFinal: true
        )
        let conversation = SavedConversation(
            id: "conversation-1",
            createdAt: Date(timeIntervalSince1970: 1234),
            title: "Folder handoff",
            durationSeconds: 42,
            recordingFileName: audioURL.lastPathComponent,
            segments: [segment],
            events: [],
            repairs: [],
            recapItems: [
                RecapItem(
                    id: "recap-1",
                    kind: .action,
                    text: "Bring the blue folder.",
                    status: .heard,
                    owner: "James",
                    sourceSegmentIDs: [segment.id],
                    confirmationID: nil
                )
            ],
            recapErrorMessage: nil,
            captionEngine: .openAIRealtime,
            provisionalSegments: [segment],
            transcriptRefinedAt: Date(timeIntervalSince1970: 1_300),
            transcriptRefinementErrorMessage: nil
        )

        _ = try archive.upsert(conversation, in: [])
        let loaded = try archive.load()

        XCTAssertEqual(loaded, [conversation])
        XCTAssertEqual(loaded.first?.segments.first?.text, segment.text)
        XCTAssertEqual(loaded.first?.recapItems.first?.sourceSegmentIDs, [segment.id])
        XCTAssertEqual(loaded.first?.captionEngine, .openAIRealtime)
        XCTAssertEqual(loaded.first?.provisionalSegments, [segment])
        XCTAssertEqual(loaded.first?.transcriptRefinedAt, Date(timeIntervalSince1970: 1_300))
    }

    func testDeletingConversationRemovesAudioAndMetadata() throws {
        let archive = ConversationArchive(rootDirectory: rootURL)
        try FileManager.default.createDirectory(at: archive.recordingsDirectory, withIntermediateDirectories: true)
        let audioURL = archive.recordingsDirectory.appendingPathComponent("delete-me.caf")
        try Data([0x43, 0x41, 0x46]).write(to: audioURL)
        let conversation = SavedConversation(
            id: "delete-me",
            createdAt: Date(),
            title: "Delete me",
            durationSeconds: 1,
            recordingFileName: audioURL.lastPathComponent,
            segments: [],
            events: [],
            repairs: [],
            recapItems: [],
            recapErrorMessage: nil
        )

        let saved = try archive.upsert(conversation, in: [])
        let remaining = try archive.delete(conversation, from: saved)

        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: audioURL.path))
        XCTAssertTrue(try archive.load().isEmpty)
    }
}
