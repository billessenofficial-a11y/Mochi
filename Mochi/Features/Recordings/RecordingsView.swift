import SwiftUI

struct RecordingsView: View {
    @EnvironmentObject private var store: ConversationStore
    @State private var pendingDeletion: SavedConversation?
    @State private var searchText = ""

    private var filteredConversations: [SavedConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.savedConversations }
        return store.savedConversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query) ||
            conversation.segments.contains {
                $0.text.localizedCaseInsensitiveContains(query) ||
                $0.speaker.displayName.localizedCaseInsensitiveContains(query)
            } ||
            conversation.recapItems.contains {
                $0.text.localizedCaseInsensitiveContains(query) ||
                ($0.owner?.localizedCaseInsensitiveContains(query) ?? false)
            } ||
            conversation.events.contains {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.sourceQuote.localizedCaseInsensitiveContains(query)
            } ||
            conversation.repairs.contains {
                $0.resolvedValue?.localizedCaseInsensitiveContains(query) ?? false
            }
        }
    }

    private var groupedConversations: [(title: String, conversations: [SavedConversation])] {
        var groups: [(String, [SavedConversation])] = []
        for conversation in filteredConversations {
            let title = sectionTitle(for: conversation.createdAt)
            if let index = groups.firstIndex(where: { $0.0 == title }) {
                groups[index].1.append(conversation)
            } else {
                groups.append((title, [conversation]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    Text("Recordings")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(MochiTheme.text)
                        .accessibilityAddTraits(.isHeader)

                    searchField

                    if store.savedConversations.isEmpty {
                        emptyState
                    } else {
                        libraryContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 42)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .mochiScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Delete this recording?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { conversation in
                Button("Delete recording", role: .destructive) {
                    store.deleteSavedConversation(conversation)
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { _ in
                Text("This permanently removes the on-device audio, transcript, and recap.")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MochiTheme.secondaryText)
            TextField("Search recordings", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MochiTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(MochiTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MochiTheme.divider.opacity(0.7)))
    }

    @ViewBuilder
    private var libraryContent: some View {
        if let message = store.libraryErrorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MochiTheme.amberStrong)
                .padding(.horizontal, 2)
        }

        if filteredConversations.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundStyle(MochiTheme.ink)
                Text("Nothing matched “\(searchText)”")
                    .font(.headline)
                Text("Try a title, phrase, or speaker name.")
                    .font(.subheadline)
                    .foregroundStyle(MochiTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .clearCueCard()
        }

        ForEach(groupedConversations, id: \.title) { group in
            MochiSectionTitle(title: group.title, detail: "\(group.conversations.count)")
                .padding(.top, 3)

            ForEach(group.conversations) { conversation in
                RecordingLibraryRow(
                    conversation: conversation,
                    open: { store.openSavedConversation(conversation) },
                    delete: { pendingDeletion = conversation }
                )
            }
        }

        Label(
            store.captionEngine == .openAIRealtime
                ? "Search and saved copies stay local. Realtime sessions use OpenAI for the accuracy pass."
                : "Search and captions run locally. Audio uploads only when you request an accuracy pass.",
            systemImage: "lock.shield.fill"
        )
        .font(.caption)
        .foregroundStyle(MochiTheme.secondaryText)
        .padding(.top, 4)
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(MochiTheme.ink)
                .accessibilityHidden(true)
            VStack(spacing: 7) {
                Text("No recordings yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(MochiTheme.text)
                Text("Completed live conversations will appear here with their audio, transcript, and recap.")
                    .font(.body)
                    .foregroundStyle(MochiTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Button("Start from Home") {
                store.selectedTab = .home
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 6)
        }
        .padding(.vertical, 10)
        .clearCueCard()
    }
}

private struct RecordingLibraryRow: View {
    let conversation: SavedConversation
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "waveform")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(MochiTheme.ink, in: Circle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text(conversation.title)
                            .font(.headline)
                            .foregroundStyle(MochiTheme.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Text(conversation.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(MochiTheme.secondaryText)

                        HStack(spacing: 12) {
                            Label(conversation.formattedDuration, systemImage: "clock")
                            Label("\(conversation.captionCount)", systemImage: "captions.bubble")
                            if conversation.confirmedRepairCount > 0 {
                                Label("\(conversation.confirmedRepairCount)", systemImage: "checkmark.seal")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MochiTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens playback, recap, and full transcript")

            Menu {
                Button(action: open) {
                    Label("Open conversation", systemImage: "arrow.up.right.square")
                }
                Button(role: .destructive, action: delete) {
                    Label("Delete recording", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(MochiTheme.secondaryText)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("More options for \(conversation.title)")
        }
        .clearCueCard()
        .shadow(color: Color.black.opacity(0.025), radius: 12, y: 5)
    }
}
