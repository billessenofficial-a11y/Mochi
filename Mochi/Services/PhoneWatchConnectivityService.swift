import Foundation
import WatchConnectivity

enum WatchCommand: String {
    case requestStart
    case togglePause
    case endConversation
    case refreshCatchUp
    case dismissNameMention
}

struct PhoneWatchSnapshot {
    let sessionState: String
    let elapsedSeconds: Int
    let consentRequired: Bool
    let latestSegment: TranscriptSegment?
    let nameMention: AttentionEvent?
    let catchUpOverview: String
    let catchUpItems: [CatchUpItem]

    var payload: [String: Any] {
        var payload: [String: Any] = [
            "sessionState": sessionState,
            "elapsedSeconds": elapsedSeconds,
            "consentRequired": consentRequired,
            "catchUpOverview": catchUpOverview,
            "catchUpItems": catchUpItems.prefix(4).map { item in
                [
                    "id": item.id,
                    "kind": item.kind.rawValue,
                    "title": item.title,
                    "text": item.text
                ]
            }
        ]

        if let latestSegment {
            payload["latestSpeaker"] = latestSegment.speaker.displayName
            payload["latestText"] = latestSegment.text
            payload["latestTimestamp"] = latestSegment.timestamp
        }

        if let nameMention {
            payload["mentionID"] = nameMention.id
            payload["mentionText"] = nameMention.sourceQuote
        }

        return payload
    }
}

@MainActor
final class PhoneWatchConnectivityService: NSObject, WCSessionDelegate {
    var onCommand: ((WatchCommand) -> Void)?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func publish(_ snapshot: PhoneWatchSnapshot) {
        guard let session, session.activationState == .activated else { return }
        let payload = snapshot.payload

        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Live messages below are opportunistic. The next state change
            // retries application context, so there is nothing to queue here.
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func receive(command rawValue: String) {
        guard let command = WatchCommand(rawValue: rawValue) else { return }
        onCommand?(command)
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        Task { @MainActor [weak self] in self?.receive(command: command) }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = message["command"] as? String,
              WatchCommand(rawValue: command) != nil else {
            replyHandler(["accepted": false])
            return
        }
        replyHandler(["accepted": true])
        Task { @MainActor [weak self] in self?.receive(command: command) }
    }
}
