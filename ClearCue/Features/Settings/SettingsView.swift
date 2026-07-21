import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ConversationStore
    @State private var nicknameText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MochiTopBar {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(ClearCueTheme.ink)
                            .frame(width: 46, height: 46)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    MochiHero(
                        title: "Make Mochi\nyours.",
                        subtitle: "Tune how Mochi recognizes you, captions conversations, and gets your attention."
                    )

                    identityPanel
                    captionEnginePanel
                    captionSizePanel
                    experiencePanel
                    privacyPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 42)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .mochiScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { nicknameText = store.nicknames.joined(separator: ", ") }
            .onDisappear { saveNicknames() }
        }
    }

    private var identityPanel: some View {
        SettingsPanel(title: "Your identity", icon: "person.crop.circle.fill") {
            VStack(spacing: 10) {
                settingsTextField("Your name", text: $store.userName)
                    .textContentType(.name)
                settingsTextField("Nicknames, separated by commas", text: $nicknameText)
                    .textInputAutocapitalization(.words)
                    .onSubmit(saveNicknames)
            }
            Text("Mochi watches captions for these names and gives you a visible cue and haptic when someone calls you.")
                .font(.caption)
                .foregroundStyle(ClearCueTheme.secondaryText)
        }
    }

    private var captionEnginePanel: some View {
        SettingsPanel(title: "Caption engine", icon: "captions.bubble.fill") {
            Picker("Transcription", selection: $store.captionEngine) {
                ForEach(CaptionEngine.allCases) { engine in
                    Text(engine.shortTitle).tag(engine)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.speechService.isListening)

            Label(store.captionEngine.detail, systemImage: store.captionEngine.systemImage)
                .font(.caption)
                .foregroundStyle(ClearCueTheme.secondaryText)
        }
    }

    private var captionSizePanel: some View {
        SettingsPanel(title: "Caption size", icon: "textformat.size") {
            HStack {
                Text("Text size")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(store.captionScale * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClearCueTheme.ink)
            }
            Slider(value: $store.captionScale, in: 0.9...1.45, step: 0.05)
                .tint(ClearCueTheme.ink)
            Text("Can you repeat that last part?")
                .font(.system(size: 18 * store.captionScale, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(ClearCueTheme.softMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var experiencePanel: some View {
        SettingsPanel(title: "Experience", icon: "sparkles") {
            Toggle(isOn: $store.hapticsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haptic cues")
                        .font(.subheadline.weight(.semibold))
                    Text("A gentle tap alongside important visual cues")
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
            }
            .tint(ClearCueTheme.ink)

            Divider()

            Text("Appearance")
                .font(.subheadline.weight(.semibold))
            Picker("Appearance", selection: $store.preferredColorScheme) {
                Text("System").tag(nil as ColorScheme?)
                Text("Light").tag(ColorScheme.light as ColorScheme?)
                Text("Dark").tag(ColorScheme.dark as ColorScheme?)
            }
            .pickerStyle(.segmented)
        }
    }

    private var privacyPanel: some View {
        SettingsPanel(title: "Privacy", icon: "lock.shield.fill") {
            Text(
                store.captionEngine == .openAIRealtime
                    ? "Realtime audio is sent to OpenAI. Saved audio and search stay on this device."
                    : "Live captions, saved audio, and search stay on this device."
            )
            .font(.subheadline)
            .foregroundStyle(ClearCueTheme.secondaryText)
        }
    }

    private func settingsTextField(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(ClearCueTheme.softMint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(ClearCueTheme.divider.opacity(0.55)))
    }

    private func saveNicknames() {
        store.nicknames = nicknameText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(ClearCueTheme.text)
            content
        }
        .clearCueCard()
        .shadow(color: Color.black.opacity(0.025), radius: 12, y: 5)
    }
}
