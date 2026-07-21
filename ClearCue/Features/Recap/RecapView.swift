import SwiftUI

struct RecapView: View {
    @EnvironmentObject private var store: ConversationStore
    @State private var showDeleteConfirmation = false
    @State private var showFullTranscript = false
    @State private var showRecordingChat = false
    @State private var showSpeakers = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    recapHero
                    if let recordingURL = store.recordingURL {
                        RecordingPlayerCard(
                            recordingURL: recordingURL,
                            playback: store.playbackService
                        )
                    }
                    transcriptRefinementStatus
                    recapGenerationStatus
                    recapSections
                    quickActions
                    verifyNotice
                    actions
                }
                .padding(20)
                .padding(.bottom, 16)
            }
            .mochiScreenBackground()
            .navigationTitle("Recap")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $store.showEvidence) { EvidenceView() }
            .sheet(isPresented: $showFullTranscript) { FullTranscriptView() }
            .sheet(isPresented: $showRecordingChat) { RecordingChatView() }
            .sheet(isPresented: $showSpeakers) { SpeakerEditorView(initialSpeakerID: nil) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSpeakers = true
                        store.selectionHaptic()
                    } label: {
                        Label("Speakers", systemImage: "person.2.fill")
                    }
                    .disabled(store.segments.isEmpty)
                }
            }
            .confirmationDialog("Delete this conversation?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete conversation", role: .destructive) { store.deleteConversation() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the audio, transcript, recap, and confirmations from Mochi.")
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Explore")
                .font(.headline)

            HStack(spacing: 12) {
                recapAction(
                    title: "Transcript",
                    detail: "Read or play",
                    icon: "text.alignleft",
                    enabled: !store.segments.isEmpty
                ) { showFullTranscript = true }

                recapAction(
                    title: "Ask Mochi",
                    detail: "Chat with it",
                    icon: "sparkles",
                    enabled: !store.segments.isEmpty && !store.isRefiningTranscript
                ) { showRecordingChat = true }
            }
        }
    }

    private func recapAction(
        title: String,
        detail: String,
        icon: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(ClearCueTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(ClearCueTheme.mint, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearCueTheme.text)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clearCueCard()
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private var recordingChatButton: some View {
        Button {
            showRecordingChat = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(ClearCueTheme.ink)
                    .background(ClearCueTheme.mint, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Chat with this recording")
                        .font(.headline)
                        .foregroundStyle(ClearCueTheme.text)
                    Text("Ask questions with playable transcript citations")
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }
            .clearCueCard()
        }
        .buttonStyle(.plain)
        .disabled(store.segments.isEmpty || store.isRefiningTranscript)
        .opacity(store.segments.isEmpty || store.isRefiningTranscript ? 0.55 : 1)
        .accessibilityHint("Opens a transcript-grounded chat for this recording")
    }

    @ViewBuilder
    private var transcriptRefinementStatus: some View {
        if store.isRefiningTranscript {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(ClearCueTheme.ink)
                Text("Improving transcript and speaker timestamps…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }
        } else if store.transcriptRefinedAt != nil {
            Label("Accuracy pass complete · speaker timestamps refined", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClearCueTheme.ink)
        } else if let message = store.transcriptRefinementErrorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ClearCueTheme.amberStrong)
                Button("Retry accuracy pass") { store.retryTranscriptRefinement() }
                    .buttonStyle(.bordered)
            }
        } else if store.canRefineTranscript {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    store.retryTranscriptRefinement()
                } label: {
                    Label("Improve transcript with OpenAI", systemImage: "waveform")
                }
                .buttonStyle(.bordered)
                Text("Uploads this recording for a speaker-aware accuracy pass. Your on-device audio remains saved until you delete it.")
                    .font(.caption)
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var recapGenerationStatus: some View {
        if let message = store.recapErrorMessage {
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(ClearCueTheme.amberStrong)
                Button {
                    store.retryRecap()
                } label: {
                    if store.isGeneratingRecap {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Retrying GPT-5.6…")
                        }
                    } else {
                        Label("Retry GPT-5.6 recap", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(store.isGeneratingRecap)
            }
        }
    }

    private var fullTranscriptButton: some View {
        Button {
            showFullTranscript = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "text.alignleft")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.white)
                    .background(ClearCueTheme.ink, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("View full transcript")
                        .font(.headline)
                        .foregroundStyle(ClearCueTheme.text)
                    Text("All \(store.segments.count) caption moments with playable timestamps")
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }
            .clearCueCard()
        }
        .buttonStyle(.plain)
        .disabled(store.segments.isEmpty)
        .opacity(store.segments.isEmpty ? 0.55 : 1)
        .accessibilityHint("Opens every caption in chronological order")
    }

    private var recapHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.recapTitle)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(ClearCueTheme.text)

            HStack(spacing: 8) {
                Label("\(store.segments.count) moments", systemImage: "captions.bubble.fill")
                if store.elapsedSeconds > 0 {
                    Label(formattedDuration, systemImage: "clock")
                }
                if store.repairs.contains(where: { $0.userConfirmed }) {
                    Label("\(store.repairs.filter { $0.userConfirmed }.count) confirmed", systemImage: "checkmark.seal.fill")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(ClearCueTheme.secondaryText)
        }
    }

    private var formattedDuration: String {
        let total = max(0, store.elapsedSeconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @ViewBuilder
    private var recapSections: some View {
        let ordered = store.recapItems.sorted { recapPriority($0.kind) < recapPriority($1.kind) }

        if !ordered.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                MochiSectionTitle(title: "What matters", detail: "\(ordered.count)")
                VStack(spacing: 0) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, item in
                        recapRow(item)
                        if index < ordered.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(ClearCueTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(ClearCueTheme.divider.opacity(0.65)))
            }
        } else if store.isGeneratingRecap {
            HStack(spacing: 10) {
                ProgressView()
                Text(store.isRefiningTranscript ? "Waiting for the accuracy pass…" : "Creating your GPT-5.6 recap…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 28)
        } else {
            ContentUnavailableView(
                "No spoken moments captured",
                systemImage: "waveform.slash",
                description: Text("The recording is still available above if audio was captured.")
            )
        }
    }

    private func recapRow(_ item: RecapItem) -> some View {
        Button {
            store.showEvidence(for: item.sourceSegmentIDs)
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: recapIcon(item.kind))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(item.kind == .unresolved ? ClearCueTheme.amberStrong : ClearCueTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(item.kind == .unresolved ? ClearCueTheme.amber : ClearCueTheme.mint, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(recapLabel(item.kind))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.kind == .unresolved ? ClearCueTheme.amberStrong : ClearCueTheme.ink)
                        if let owner = item.owner, !owner.isEmpty {
                            Text("· \(owner)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ClearCueTheme.secondaryText)
                        }
                    }
                    Text(item.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(ClearCueTheme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: store.recordingURL == nil ? "chevron.right" : "waveform.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
                    .padding(.top, 10)
            }
            .padding(15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens supporting transcript and playable audio evidence")
    }

    private func recapPriority(_ kind: RecapKind) -> Int {
        switch kind {
        case .unresolved: 0
        case .action: 1
        case .decision: 2
        case .detail: 3
        }
    }

    private func recapIcon(_ kind: RecapKind) -> String {
        switch kind {
        case .unresolved: "questionmark"
        case .action: "checklist"
        case .decision: "checkmark"
        case .detail: "quote.opening"
        }
    }

    private func recapLabel(_ kind: RecapKind) -> String {
        switch kind {
        case .unresolved: "Needs confirmation"
        case .action: "Action"
        case .decision: "Decision"
        case .detail: "Worth remembering"
        }
    }

    private var verifyNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(ClearCueTheme.ink)
            Text("AI-generated recap. Confirm medical, legal, financial, and other high-stakes details directly.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(ClearCueTheme.secondaryText)
        }
        .font(.caption)
        .padding(.horizontal, 2)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button("Start another conversation") { store.startAnotherConversation() }
                .buttonStyle(PrimaryButtonStyle())
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete conversation", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct FullTranscriptView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredSegments: [TranscriptSegment] {
        let ordered = store.segments.sorted { $0.startSeconds < $1.startSeconds }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ordered
        }
        return ordered.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            $0.speaker.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if let recordingURL = store.recordingURL {
                        RecordingPlayerCard(
                            recordingURL: recordingURL,
                            playback: store.playbackService
                        )
                    }

                    HStack {
                        Label("\(filteredSegments.count) caption moments", systemImage: "captions.bubble.fill")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(store.transcriptRefinedAt == nil ? "Live AI transcript" : "Full-recording accuracy pass")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ClearCueTheme.secondaryText)
                    }

                    if filteredSegments.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 44)
                    }

                    ForEach(filteredSegments) { segment in
                        FullTranscriptRow(segment: segment)
                    }

                    Text("Captions may contain errors. Confirm important details directly and use the recording as the original evidence.")
                        .font(.footnote)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                        .padding(.top, 6)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(ClearCueTheme.canvas)
            .navigationTitle("Full transcript")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search transcript")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct FullTranscriptRow: View {
    @EnvironmentObject private var store: ConversationStore
    let segment: TranscriptSegment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(speakerColor)
                    .frame(width: 12, height: 12)
                Text(segment.speaker.displayName.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.5)
                Spacer()
                Text(segment.timestamp)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }

            Text(segment.text)
                .font(.body.weight(.medium))
                .foregroundStyle(ClearCueTheme.text)
                .fixedSize(horizontal: false, vertical: true)

            if store.recordingURL != nil {
                Button {
                    store.playEvidence(segment)
                } label: {
                    Label("Play from \(segment.timestamp)", systemImage: "play.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(ClearCueTheme.ink)
            }
        }
        .clearCueCard()
        .accessibilityElement(children: .contain)
    }

    private var speakerColor: Color {
        switch segment.speaker.style {
        case .mint: ClearCueTheme.mint
        case .blue: ClearCueTheme.blue
        case .lilac: ClearCueTheme.lilac
        case .neutral: ClearCueTheme.secondaryText
        }
    }
}

private struct RecordingPlayerCard: View {
    let recordingURL: URL
    @ObservedObject var playback: AudioPlaybackService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Session recording", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                Text("On this device")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }

            HStack(spacing: 14) {
                Button {
                    playback.toggle(url: recordingURL)
                } label: {
                    Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.white)
                        .background(ClearCueTheme.ink, in: Circle())
                }
                .accessibilityLabel(playback.isPlaying ? "Pause recording" : "Play recording")

                VStack(spacing: 6) {
                    Slider(
                        value: Binding(
                            get: { playback.currentTime },
                            set: { playback.seek(to: $0) }
                        ),
                        in: 0...max(playback.duration, 0.01)
                    )
                    HStack {
                        Text(format(playback.currentTime))
                        Spacer()
                        Text(format(playback.duration))
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ClearCueTheme.secondaryText)
                }
            }
        }
        .clearCueCard()
        .onAppear { try? playback.load(recordingURL) }
    }

    private func format(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct StatusPill: View {
    let status: RecapStatus

    var body: some View {
        Label(status.label, systemImage: icon)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
    }

    private var icon: String {
        switch status {
        case .confirmed: "checkmark.seal.fill"
        case .heard: "ear.fill"
        case .unresolved: "questionmark.circle.fill"
        }
    }

    private var foreground: Color {
        switch status {
        case .confirmed: ClearCueTheme.ink
        case .heard: ClearCueTheme.secondaryText
        case .unresolved: ClearCueTheme.amberStrong
        }
    }

    private var background: Color {
        switch status {
        case .confirmed: ClearCueTheme.mint
        case .heard: ClearCueTheme.surface
        case .unresolved: ClearCueTheme.amber
        }
    }
}
