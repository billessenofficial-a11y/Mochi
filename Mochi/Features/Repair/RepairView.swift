import SwiftUI

struct RepairView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    let event: AttentionEvent
    @State private var manualAnswer = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    reason
                    evidence
                    candidates
                    showSpeakerButton
                    manualEntry
                    unresolvedButton
                }
                .padding(20)
            }
            .background(MochiTheme.canvas)
            .navigationTitle("Clarify this moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
    }

    private var reason: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Why Mochi flagged this", systemImage: "exclamationmark.bubble.fill")
                .font(.headline)
                .foregroundStyle(MochiTheme.amberStrong)
            Text(event.explanation)
                .font(.title3)
                .foregroundStyle(MochiTheme.text)
            Text("AI suggestion—confirm important details directly.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MochiTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(MochiTheme.amber, in: RoundedRectangle(cornerRadius: 20))
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Original caption")
                    .font(.headline)
                Spacer()
                Button("View source") { store.showEvidence(for: event.sourceSegmentIDs) }
                    .font(.subheadline.weight(.semibold))
            }
            Text("“\(event.sourceQuote)”")
                .font(.title3.weight(.semibold))
                .foregroundStyle(MochiTheme.text)
            Text("The original caption stays unchanged after confirmation.")
                .font(.footnote)
                .foregroundStyle(MochiTheme.secondaryText)
        }
        .clearCueCard()
        .sheet(isPresented: $store.showEvidence) { EvidenceView() }
    }

    @ViewBuilder
    private var candidates: some View {
        if !event.candidates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("What was confirmed?")
                    .font(.headline)
                ForEach(event.candidates, id: \.self) { candidate in
                    Button {
                        store.resolveActiveEvent(with: candidate)
                    } label: {
                        HStack {
                            Text(candidate)
                                .font(.title3.weight(.bold))
                            Spacer()
                            Image(systemName: "checkmark.circle")
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .tint(MochiTheme.ink)
                }
            }
        }
    }

    private var showSpeakerButton: some View {
        Button {
            store.showSpeakerCard = true
        } label: {
            Label("Show speaker", systemImage: "rectangle.on.rectangle.angled")
        }
        .buttonStyle(PrimaryButtonStyle())
        .accessibilityHint("Shows only the clarification question in very large text")
    }

    private var manualEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or enter the answer")
                .font(.headline)
            TextField("Confirmed detail", text: $manualAnswer)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .submitLabel(.done)
            Button("Save typed answer") {
                store.resolveActiveEvent(with: manualAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .buttonStyle(.borderedProminent)
            .tint(MochiTheme.ink)
            .disabled(manualAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var unresolvedButton: some View {
        Button("Couldn’t confirm") {
            store.markActiveEventUnresolved()
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .foregroundStyle(MochiTheme.secondaryText)
    }
}

struct SpeakerCardView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    let event: AttentionEvent

    var body: some View {
        ZStack {
            MochiTheme.ink.ignoresSafeArea()
            VStack(spacing: 32) {
                HStack {
                    Label("Clarification", systemImage: "quote.bubble.fill")
                        .font(.headline)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 48, height: 48)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .accessibilityLabel("Close speaker card")
                }

                Spacer()

                Text(event.clarificationPrompt)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.58)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if !event.candidates.isEmpty {
                    Text("Tap the answer you meant")
                        .font(.headline)
                        .opacity(0.8)

                    HStack(spacing: 12) {
                        ForEach(event.candidates, id: \.self) { candidate in
                            Button(candidate) {
                                store.resolveActiveEvent(with: candidate)
                            }
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .foregroundStyle(MochiTheme.ink)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }
            }
            .foregroundStyle(Color.white)
            .padding(24)
        }
        .statusBarHidden()
        .accessibilityElement(children: .contain)
    }
}
