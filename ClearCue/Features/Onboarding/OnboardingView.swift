import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let completed: () -> Void

    @State private var step = 0
    @State private var nicknameText = ""
    @State private var mascotVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack {
                    MochiWordmark(size: 32)
                    Spacer()
                    Text("\(step + 1) of 2")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }

                if step == 0 { identityStep } else { readinessStep }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background {
            LinearGradient(
                colors: [ClearCueTheme.softMint, ClearCueTheme.canvas, ClearCueTheme.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .task { await store.prepareHearingModel() }
        .onAppear {
            nicknameText = store.nicknames.joined(separator: ", ")
            withAnimation(reduceMotion ? nil : .spring(response: 0.75, dampingFraction: 0.78)) {
                mascotVisible = true
            }
        }
        .animation(.snappy(duration: 0.35), value: step)
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Spacer()
                Image("MochiMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 154, height: 154)
                    .scaleEffect(mascotVisible ? 1 : 0.82)
                    .opacity(mascotVisible ? 1 : 0)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("What should Mochi listen for?")
                    .font(.system(size: 37, weight: .bold, design: .rounded))
                    .foregroundStyle(ClearCueTheme.text)
                Text("When someone says your name, Mochi can bring the moment forward with a visible cue and a gentle tap.")
                    .font(.body)
                    .foregroundStyle(ClearCueTheme.secondaryText)
                    .lineSpacing(4)
            }

            VStack(spacing: 14) {
                profileField("Your name", text: $store.userName, icon: "person.fill")
                profileField("Nicknames (optional)", text: $nicknameText, icon: "quote.bubble.fill")
                Text("Separate multiple nicknames with commas. You can change these anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(ClearCueTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Continue") {
                store.nicknames = parsedNicknames
                store.selectionHaptic()
                step = 1
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(store.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var readinessStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Your hearing backup, ready before you need it.")
                    .font(.system(size: 37, weight: .bold, design: .rounded))
                    .foregroundStyle(ClearCueTheme.text)
                Text("Mochi prepares multilingual Whisper and FluidAudio now—never in the middle of a conversation.")
                    .font(.body)
                    .foregroundStyle(ClearCueTheme.secondaryText)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 18) {
                readinessRow("Multilingual captions", detail: "WhisperKit on device", ready: store.isHearingReady)
                readinessRow("Live speaker labels", detail: "FluidAudio on device", ready: store.speechService.isDiarizationReady)
                readinessRow("Private recording library", detail: "Stored only on this device", ready: true)

                if !store.isHearingReady || !store.speechService.isDiarizationReady {
                    ProgressView(value: store.speechService.preparationProgress)
                        .tint(ClearCueTheme.ink)
                }
            }
            .clearCueCard()

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(ClearCueTheme.ink)
                Text("You choose when listening starts. Realtime mode sends live audio to OpenAI; on-device mode keeps captioning local.")
                    .font(.footnote)
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }

            Button(store.isHearingReady && store.speechService.isDiarizationReady ? "Meet Mochi" : "Preparing Mochi…") {
                store.selectionHaptic()
                completed()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!store.isHearingReady || !store.speechService.isDiarizationReady)
            .opacity(store.isHearingReady && store.speechService.isDiarizationReady ? 1 : 0.5)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func profileField(_ title: String, text: Binding<String>, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(ClearCueTheme.ink)
                .frame(width: 24)
            TextField(title, text: text)
                .textContentType(title == "Your name" ? .name : .nickname)
                .textInputAutocapitalization(.words)
        }
        .padding(16)
        .background(ClearCueTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ClearCueTheme.divider.opacity(0.7)))
    }

    private func readinessRow(_ title: String, detail: String, ready: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle.dotted")
                .font(.title3)
                .foregroundStyle(ready ? ClearCueTheme.ink : ClearCueTheme.secondaryText)
                .symbolEffect(.bounce, value: ready)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(ClearCueTheme.secondaryText)
            }
        }
    }

    private var parsedNicknames: [String] {
        nicknameText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
