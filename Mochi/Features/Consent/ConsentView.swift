import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss
    @State private var informedParticipants = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero
                        if store.mode.capturesAudio { activeFeatures }
                        consent
                        processingNote
                    }
                    .padding(24)
                }

                Button {
                    store.confirmConsentAndStart()
                } label: {
                    Text(store.mode.capturesAudio ? "Start listening" : "Start demo")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!informedParticipants)
                .opacity(informedParticipants ? 1 : 0.45)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)
            }
            .background(MochiTheme.canvas)
            .navigationTitle("Ready to listen?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 16) {
            Image("MochiMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .padding(7)
                .background(MochiTheme.softMint, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(heroTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(heroDetail)
                    .font(.subheadline)
                    .foregroundStyle(MochiTheme.secondaryText)
            }
        }
    }

    private var activeFeatures: some View {
        HStack(spacing: 9) {
            if store.sessionCaptionsEnabled {
                featureChip("Captions", icon: "captions.bubble.fill")
            }
            if store.sessionVoiceLiftEnabled {
                featureChip("Voice Lift · \(liftLabel)", icon: "headphones")
            }
        }
    }

    private func featureChip(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MochiTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MochiTheme.mint, in: Capsule())
    }

    private var consent: some View {
        Button {
            informedParticipants.toggle()
            store.selectionHaptic()
        } label: {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: informedParticipants ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(informedParticipants ? MochiTheme.ink : MochiTheme.secondaryText)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Everyone nearby knows I’m recording")
                        .font(.headline)
                        .foregroundStyle(MochiTheme.text)
                    Text("Consent laws vary—ask before you capture.")
                        .font(.caption)
                        .foregroundStyle(MochiTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var processingNote: some View {
        Label(processingText, systemImage: processingIcon)
            .font(.caption)
            .foregroundStyle(MochiTheme.secondaryText)
    }

    private var processingText: String {
        guard store.mode.capturesAudio else { return "This demo uses simulated data and captures no audio." }
        if !store.sessionCaptionsEnabled {
            return "Voice Lift runs on this device. The session recording stays here until you delete it."
        }
        return store.captionEngine == .openAIRealtime
            ? "Realtime audio goes to OpenAI. Your saved recording stays on this device until you delete it."
            : "Captions and speaker labels run on this device."
    }

    private var processingIcon: String {
        if !store.sessionCaptionsEnabled { return "iphone" }
        return store.captionEngine == .openAIRealtime ? "cloud" : "iphone"
    }

    private var heroTitle: String {
        if store.mode == .recording { return "Record and remember" }
        if store.sessionCaptionsEnabled, store.sessionVoiceLiftEnabled { return "Hear and read along" }
        if store.sessionVoiceLiftEnabled { return "Lift nearby voices" }
        return "Live captions"
    }

    private var heroDetail: String {
        if store.sessionCaptionsEnabled, store.sessionVoiceLiftEnabled {
            return "Clearer headphone audio with live captions as backup."
        }
        if store.sessionVoiceLiftEnabled {
            return "Hear the iPhone microphone through connected headphones."
        }
        return "Captions, speaker labels, and a replayable transcript."
    }

    private var liftLabel: String {
        if store.voiceLiftGainDB <= 3 { return "Gentle" }
        if store.voiceLiftGainDB <= 6 { return "Medium" }
        return "Strong"
    }
}
