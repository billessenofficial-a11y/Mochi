@preconcurrency import AVFoundation
import Foundation

struct ConversationArchive {
    let recordingsDirectory: URL
    private let metadataURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default, rootDirectory: URL? = nil) {
        self.fileManager = fileManager
        let root = rootDirectory ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        recordingsDirectory = root.appendingPathComponent("Recordings", isDirectory: true)
        metadataURL = root.appendingPathComponent("mochi-conversations.json")
    }

    func load() throws -> [SavedConversation] {
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        var conversations: [SavedConversation] = []

        if fileManager.fileExists(atPath: metadataURL.path) {
            let data = try Data(contentsOf: metadataURL)
            conversations = try JSONDecoder().decode([SavedConversation].self, from: data)
        }

        conversations.removeAll { !fileManager.fileExists(atPath: recordingURL(for: $0).path) }
        let knownFiles = Set(conversations.map(\.recordingFileName))
        let audioFiles = try fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        for audioURL in audioFiles where audioURL.pathExtension.lowercased() == "caf" && !knownFiles.contains(audioURL.lastPathComponent) {
            let values = try? audioURL.resourceValues(forKeys: [.creationDateKey])
            let createdAt = values?.creationDate ?? Date()
            conversations.append(
                SavedConversation(
                    id: "recovered-\(audioURL.deletingPathExtension().lastPathComponent)",
                    createdAt: createdAt,
                    title: "Recovered recording",
                    durationSeconds: Self.audioDuration(at: audioURL),
                    recordingFileName: audioURL.lastPathComponent,
                    segments: [],
                    events: [],
                    repairs: [],
                    recapItems: [],
                    recapErrorMessage: nil
                )
            )
        }

        let sorted = conversations.sorted { $0.createdAt > $1.createdAt }
        if sorted != conversations || sorted.count != knownFiles.count {
            try persist(sorted)
        }
        return sorted
    }

    func upsert(_ conversation: SavedConversation, in conversations: [SavedConversation]) throws -> [SavedConversation] {
        var updated = conversations.filter { $0.id != conversation.id }
        updated.append(conversation)
        updated.sort { $0.createdAt > $1.createdAt }
        try persist(updated)
        return updated
    }

    func delete(_ conversation: SavedConversation, from conversations: [SavedConversation]) throws -> [SavedConversation] {
        let audioURL = recordingURL(for: conversation)
        if fileManager.fileExists(atPath: audioURL.path) {
            try fileManager.removeItem(at: audioURL)
        }
        let updated = conversations.filter { $0.id != conversation.id }
        try persist(updated)
        return updated
    }

    func recordingURL(for conversation: SavedConversation) -> URL {
        recordingsDirectory.appendingPathComponent(conversation.recordingFileName)
    }

    private func persist(_ conversations: [SavedConversation]) throws {
        let parent = metadataURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(conversations).write(to: metadataURL, options: .atomic)
    }

    private static func audioDuration(at url: URL) -> Int {
        guard let file = try? AVAudioFile(forReading: url), file.fileFormat.sampleRate > 0 else { return 0 }
        return Int((Double(file.length) / file.fileFormat.sampleRate).rounded())
    }
}
