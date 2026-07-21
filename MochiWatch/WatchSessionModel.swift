import Foundation
import WatchConnectivity
import WatchKit

enum WatchSessionState: String, Sendable {
    case ready
    case consent
    case listening
    case paused
    case finishing
    case complete
}

enum WatchCatchUpKind: String, Sendable {
    case needsYou
    case decision
    case action
    case detail
    case recent
}

struct WatchCatchUpItem: Identifiable, Sendable {
    let id: String
    let kind: WatchCatchUpKind
    let title: String
    let text: String
}

private struct WatchPayload: Sendable {
    let state: WatchSessionState
    let elapsedSeconds: Int
    let latestSpeaker: String
    let latestText: String
    let latestTimestamp: String
    let mentionID: String
    let mentionText: String
    let catchUpOverview: String
    let catchUpItems: [WatchCatchUpItem]
}

@MainActor
final class WatchSessionModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var state: WatchSessionState = .ready
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var snapshotDate = Date()
    @Published private(set) var latestSpeaker = ""
    @Published private(set) var latestText = ""
    @Published private(set) var latestTimestamp = ""
    @Published private(set) var mentionID = ""
    @Published private(set) var mentionText = ""
    @Published private(set) var catchUpOverview = "Mochi will summarize the conversation as it develops."
    @Published private(set) var catchUpItems: [WatchCatchUpItem] = []
    @Published private(set) var isReachable = false
    @Published var connectionMessage: String?

    private let session: WCSession?
    private var lastHapticMentionID = ""

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-watchActivePreview") {
            state = .listening
            elapsedSeconds = 42
            latestSpeaker = "Maya"
            latestText = "James, can you bring the blue folder?"
            latestTimestamp = "0:05"
            mentionID = "preview-mention"
            mentionText = latestText
            catchUpOverview = "The group is confirming Tuesday’s meetup. One request is directed to you."
            catchUpItems = [
                WatchCatchUpItem(
                    id: "preview-action",
                    kind: .needsYou,
                    title: "Bring blue folder",
                    text: "Maya asked you to bring the blue folder."
                )
            ]
        }
        if ProcessInfo.processInfo.arguments.contains("-watchStartCommandPreview") {
            Task { @MainActor [weak self] in
                for _ in 0..<20 {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard let self else { return }
                    if self.session?.isReachable == true {
                        self.send("requestStart")
                        return
                    }
                }
            }
        }
        #endif
    }

    var isActive: Bool {
        state == .listening || state == .paused || state == .finishing
    }

    func displayElapsed(at date: Date) -> Int {
        guard state == .listening else { return elapsedSeconds }
        return elapsedSeconds + max(0, Int(date.timeIntervalSince(snapshotDate)))
    }

    func send(_ command: String) {
        guard let session, session.activationState == .activated, session.isReachable else {
            connectionMessage = "Keep your iPhone nearby and open Mochi once."
            WKInterfaceDevice.current().play(.failure)
            return
        }

        connectionMessage = nil
        session.sendMessage(
            ["command": command],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    func acknowledgeMention() {
        send("dismissNameMention")
        mentionID = ""
        mentionText = ""
    }

    private func apply(_ payload: WatchPayload) {
        let isNewMention = !payload.mentionID.isEmpty && payload.mentionID != lastHapticMentionID

        state = payload.state
        elapsedSeconds = payload.elapsedSeconds
        snapshotDate = .now
        latestSpeaker = payload.latestSpeaker
        latestText = payload.latestText
        latestTimestamp = payload.latestTimestamp
        mentionID = payload.mentionID
        mentionText = payload.mentionText
        catchUpOverview = payload.catchUpOverview
        catchUpItems = payload.catchUpItems
        isReachable = session?.isReachable ?? false

        if isNewMention {
            lastHapticMentionID = payload.mentionID
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private nonisolated static func decode(_ message: [String: Any]) -> WatchPayload {
        let rawState = message["sessionState"] as? String ?? "ready"
        let state = WatchSessionState(rawValue: rawState) ?? .ready
        let rawItems = message["catchUpItems"] as? [[String: Any]] ?? []
        let items = rawItems.compactMap { item -> WatchCatchUpItem? in
            guard let id = item["id"] as? String,
                  let title = item["title"] as? String,
                  let text = item["text"] as? String else { return nil }
            return WatchCatchUpItem(
                id: id,
                kind: WatchCatchUpKind(rawValue: item["kind"] as? String ?? "recent") ?? .recent,
                title: title,
                text: text
            )
        }

        return WatchPayload(
            state: state,
            elapsedSeconds: message["elapsedSeconds"] as? Int ?? 0,
            latestSpeaker: message["latestSpeaker"] as? String ?? "",
            latestText: message["latestText"] as? String ?? "",
            latestTimestamp: message["latestTimestamp"] as? String ?? "",
            mentionID: message["mentionID"] as? String ?? "",
            mentionText: message["mentionText"] as? String ?? "",
            catchUpOverview: message["catchUpOverview"] as? String ?? "",
            catchUpItems: items
        )
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in self?.isReachable = reachable }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in self?.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let payload = Self.decode(applicationContext)
        Task { @MainActor [weak self] in self?.apply(payload) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let payload = Self.decode(message)
        Task { @MainActor [weak self] in self?.apply(payload) }
    }
}
