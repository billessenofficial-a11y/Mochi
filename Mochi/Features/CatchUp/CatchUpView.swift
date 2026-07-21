import SwiftUI

struct CatchUpView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss

    private var items: [CatchUpItem] {
        guard let generated = store.catchUpBrief else { return store.currentCatchUp }
        return generated.items.map {
            CatchUpItem(
                id: "generated-\($0.id)",
                kind: $0.kind,
                title: $0.title,
                text: $0.text,
                sourceSegmentIDs: $0.sourceSegmentIDs
            )
        }
    }

    private var needsYou: [CatchUpItem] {
        items.filter { $0.kind == .needsYou }
    }

    private var remember: [CatchUpItem] {
        items.filter { $0.kind != .needsYou }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    overviewCard
                    generationStatus

                    if items.isEmpty {
                        emptyState
                    } else {
                        if !needsYou.isEmpty {
                            insightSection(
                                "Needs you",
                                subtitle: "Questions or moments that may need a response",
                                items: needsYou
                            )
                        }
                        if !remember.isEmpty {
                            insightSection(
                                "Remember",
                                subtitle: "Decisions, actions, and useful context",
                                items: remember
                            )
                        }
                    }

                    Label(
                        "Grounded in the live transcript. Tap any item to see its exact source.",
                        systemImage: "link"
                    )
                    .font(.caption)
                    .foregroundStyle(MochiTheme.secondaryText)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .mochiScreenBackground()
            .navigationTitle("Catch up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.refreshCatchUp(force: true)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isGeneratingCatchUp || store.segments.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $store.showEvidence) { EvidenceView() }
            .task { store.refreshCatchUp() }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Right now", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.7)
                Spacer()
                Text("\(store.segments.count) moments")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Text(store.catchUpOverview)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(MochiTheme.ink, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: MochiTheme.ink.opacity(0.14), radius: 18, y: 9)
    }

    @ViewBuilder
    private var generationStatus: some View {
        if store.isGeneratingCatchUp {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(MochiTheme.ink)
                Text("Mochi is finding what matters…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MochiTheme.secondaryText)
            }
        } else if let message = store.catchUpErrorMessage {
            Label(message, systemImage: "iphone")
                .font(.caption.weight(.medium))
                .foregroundStyle(MochiTheme.secondaryText)
        }
    }

    private func insightSection(
        _ title: String,
        subtitle: String,
        items: [CatchUpItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MochiTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MochiTheme.secondaryText)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    insightRow(item)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(MochiTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(MochiTheme.divider.opacity(0.65)))
        }
    }

    private func insightRow(_ item: CatchUpItem) -> some View {
        Button {
            store.showEvidence(for: item.sourceSegmentIDs)
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: icon(for: item.kind))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(foreground(for: item.kind))
                    .frame(width: 38, height: 38)
                    .background(background(for: item.kind), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(foreground(for: item.kind))
                    Text(item.text)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(MochiTheme.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MochiTheme.secondaryText)
                    .padding(.top, 11)
            }
            .padding(15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the exact transcript source")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.title)
                .foregroundStyle(MochiTheme.ink)
            Text("Nothing to catch up yet")
                .font(.headline)
            Text("Mochi will surface questions, decisions, and useful context as the conversation develops.")
                .font(.subheadline)
                .foregroundStyle(MochiTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .clearCueCard()
    }

    private func icon(for kind: CatchUpKind) -> String {
        switch kind {
        case .needsYou: "person.crop.circle.badge.exclamationmark"
        case .decision: "checkmark.seal.fill"
        case .action: "checklist"
        case .detail: "exclamationmark.circle.fill"
        case .recent: "clock.fill"
        }
    }

    private func foreground(for kind: CatchUpKind) -> Color {
        kind == .needsYou ? MochiTheme.amberStrong : MochiTheme.ink
    }

    private func background(for kind: CatchUpKind) -> Color {
        kind == .needsYou ? MochiTheme.amber : MochiTheme.mint
    }
}

struct EvidenceView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss

    private var evidence: [TranscriptSegment] {
        store.segments.filter { store.selectedEvidenceIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Source transcript", systemImage: "link")
                        .font(.headline)
                        .foregroundStyle(MochiTheme.ink)

                    if evidence.isEmpty {
                        Text("This source is not available in the current live transcript.")
                            .foregroundStyle(MochiTheme.secondaryText)
                    }

                    ForEach(evidence) { segment in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(segment.speaker.displayName)
                                    .font(.caption.weight(.bold))
                                Spacer()
                                Text(segment.timestamp)
                                    .font(.caption.monospacedDigit())
                            }
                            Text(segment.text)
                                .font(.title3.weight(.semibold))
                            if store.recordingURL != nil {
                                Button {
                                    store.playEvidence(segment)
                                } label: {
                                    Label("Play from \(segment.timestamp)", systemImage: "play.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .tint(MochiTheme.ink)
                            }
                        }
                        .clearCueCard()
                    }

                    Text("Confirmed answers are stored as annotations. They never overwrite this original transcript or recording.")
                        .font(.footnote)
                        .foregroundStyle(MochiTheme.secondaryText)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .mochiScreenBackground()
            .navigationTitle("Evidence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
