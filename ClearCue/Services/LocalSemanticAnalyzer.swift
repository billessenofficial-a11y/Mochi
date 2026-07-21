import Foundation

struct LocalSemanticAnalyzer {
    private let timePattern = #"\b(?:1[0-2]|[1-9])(?::[0-5][0-9])?\s?(?:a\.?m\.?|p\.?m\.?)?\b"#
    private let moneyPattern = #"(?:\$|₱)\s?\d+(?:[.,]\d+)?"#

    func analyze(segment: TranscriptSegment, userName: String, aliases: [String] = []) -> [AttentionEvent] {
        guard segment.isFinal else { return [] }

        var events: [AttentionEvent] = []
        let text = segment.text
        let lower = text.lowercased()

        let names = ([userName] + aliases)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if names.contains(where: { lower.contains($0.lowercased()) }) {
            events.append(
                AttentionEvent(
                    id: "name-\(segment.id)",
                    type: .nameMention,
                    sourceSegmentIDs: [segment.id],
                    title: "You were mentioned",
                    explanation: "Someone may be speaking directly to you.",
                    sourceQuote: text,
                    detailType: "name",
                    candidates: [],
                    clarificationPrompt: "Could you say that again for me?",
                    state: .new
                )
            )
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") || startsLikeAQuestion(lower) {
            events.append(
                AttentionEvent(
                    id: "question-\(segment.id)",
                    type: .directQuestion,
                    sourceSegmentIDs: [segment.id],
                    title: "Question for the group",
                    explanation: "A question may need a response.",
                    sourceQuote: text,
                    detailType: nil,
                    candidates: [],
                    clarificationPrompt: "Could you repeat the question, please?",
                    state: .new
                )
            )
        }

        if containsMatch(timePattern, in: text) || containsMatch(moneyPattern, in: text) {
            events.append(
                AttentionEvent(
                    id: "detail-\(segment.id)",
                    type: .criticalDetail,
                    sourceSegmentIDs: [segment.id],
                    title: "Important detail",
                    explanation: "A time or amount was mentioned. It may be worth checking.",
                    sourceQuote: text,
                    detailType: "time or amount",
                    candidates: [],
                    clarificationPrompt: "Could you repeat that detail, please?",
                    state: .new
                )
            )
        }

        return deduplicated(events)
    }

    private func startsLikeAQuestion(_ text: String) -> Bool {
        ["who ", "what ", "when ", "where ", "why ", "how ", "can ", "could ", "would ", "are ", "is ", "do ", "did "]
            .contains(where: text.hasPrefix)
    }

    private func containsMatch(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func deduplicated(_ events: [AttentionEvent]) -> [AttentionEvent] {
        var seen = Set<String>()
        return events.filter { seen.insert($0.id).inserted }
    }
}
