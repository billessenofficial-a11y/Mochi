import SwiftUI

struct SpeakerEditorView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    let initialSpeakerID: String?

    @State private var drafts: [String: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who’s speaking?")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Names update the live captions, saved transcript, search, recap, and recording chat.")
                            .font(.subheadline)
                            .foregroundStyle(MochiTheme.secondaryText)
                    }

                    ForEach(store.knownSpeakers) { speaker in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(color(for: speaker.style))
                                Text(initials(for: drafts[speaker.id] ?? speaker.displayName))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MochiTheme.text)
                            }
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(speaker.id.replacingOccurrences(of: "-", with: " ").capitalized)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MochiTheme.secondaryText)
                                TextField("Speaker name", text: binding(for: speaker))
                                    .font(.headline)
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.done)
                                    .onSubmit { save(speaker) }
                            }
                        }
                        .padding(16)
                        .background(
                            initialSpeakerID == speaker.id ? MochiTheme.softMint : MochiTheme.surface,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(MochiTheme.divider.opacity(0.65)))
                    }
                }
                .padding(20)
            }
            .background(MochiTheme.canvas)
            .navigationTitle("Speakers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        for speaker in store.knownSpeakers { save(speaker) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                drafts = Dictionary(uniqueKeysWithValues: store.knownSpeakers.map { ($0.id, $0.displayName) })
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func binding(for speaker: Speaker) -> Binding<String> {
        Binding(
            get: { drafts[speaker.id] ?? speaker.displayName },
            set: { drafts[speaker.id] = $0 }
        )
    }

    private func save(_ speaker: Speaker) {
        store.renameSpeaker(id: speaker.id, to: drafts[speaker.id] ?? speaker.displayName)
    }

    private func initials(for name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    private func color(for style: SpeakerStyle) -> Color {
        switch style {
        case .mint: MochiTheme.mint
        case .blue: MochiTheme.blue
        case .lilac: MochiTheme.lilac
        case .neutral: MochiTheme.divider
        }
    }
}
