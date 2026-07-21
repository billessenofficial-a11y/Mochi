import SwiftUI

struct RecordingChatView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [RecordingChatMessage] = []
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private let suggestions = [
        "What did I agree to?",
        "What still needs confirmation?",
        "Summarize the key details."
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        intro

                        if messages.isEmpty {
                            suggestionList
                        }

                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isSending {
                            HStack(spacing: 9) {
                                ProgressView()
                                Text("Mochi is checking the transcript…")
                            }
                            .font(.subheadline)
                            .foregroundStyle(ClearCueTheme.secondaryText)
                            .padding(14)
                        }

                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(ClearCueTheme.amberStrong)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 10)
                }
                .background(ClearCueTheme.canvas)
                .onChange(of: messages.last?.id) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .navigationTitle("Chat with recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
        }
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(ClearCueTheme.ink)
            Text("Ask about this recording. Answers use its transcript only and link back to playable moments.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(ClearCueTheme.secondaryText)
        }
        .padding(14)
        .background(ClearCueTheme.mint.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Try asking")
                .font(.caption.weight(.bold))
                .foregroundStyle(ClearCueTheme.secondaryText)
            ForEach(suggestions, id: \.self) { suggestion in
                Button(suggestion) { send(suggestion) }
                    .buttonStyle(.bordered)
                    .tint(ClearCueTheme.ink)
            }
        }
        .padding(.vertical, 8)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask about this recording", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(ClearCueTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ClearCueTheme.divider, lineWidth: 1)
                }
                .submitLabel(.send)
                .onSubmit { sendDraft() }

            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(ClearCueTheme.ink, in: Circle())
            }
            .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Send question")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendDraft() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        draft = ""
        send(question)
    }

    private func send(_ question: String) {
        guard !isSending, !store.segments.isEmpty else { return }
        let userMessage = RecordingChatMessage(role: .user, text: question)
        messages.append(userMessage)
        errorMessage = nil
        isSending = true

        Task {
            do {
                let answer = try await ClearCueAPI.shared.askRecording(
                    question: question,
                    segments: store.segments,
                    history: Array(messages.dropLast())
                )
                let validIDs = Set(store.segments.map(\.id))
                messages.append(
                    RecordingChatMessage(
                        role: .assistant,
                        text: answer.answer,
                        sourceSegmentIDs: answer.sourceSegmentIDs.filter { validIDs.contains($0) }
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

private struct ChatBubble: View {
    @EnvironmentObject private var store: ConversationStore
    let message: RecordingChatMessage

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 9) {
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.role == .user ? Color.white : ClearCueTheme.text)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .background(
                    message.role == .user ? ClearCueTheme.ink : ClearCueTheme.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

            if !message.sourceSegmentIDs.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(sourceSegments) { segment in
                            Button {
                                store.playEvidence(segment)
                            } label: {
                                Label(segment.timestamp, systemImage: "play.circle.fill")
                            }
                            .buttonStyle(.bordered)
                            .tint(ClearCueTheme.ink)
                            .font(.caption.weight(.semibold))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var sourceSegments: [TranscriptSegment] {
        message.sourceSegmentIDs.compactMap { id in
            store.segments.first { $0.id == id }
        }
    }
}
