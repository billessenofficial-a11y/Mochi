import SwiftUI

struct AssistHomeView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var showHearingTools = ProcessInfo.processInfo.arguments.contains("-hearingToolsPreview")

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        topBar
                        Spacer(minLength: 2)
                        listenControl
                        welcome
                        featureControls
                        hearingTools
                    }
                    .frame(minHeight: max(0, proxy.size.height - 18), alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
            .mochiScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $store.showConsent) {
                ConsentView()
                    .presentationDetents([.large])
            }
            .task { await store.prepareHearingModel() }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var topBar: some View {
        MochiTopBar {
            Text(store.userName.isEmpty ? "Your space" : "Hi, \(store.userName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClearCueTheme.secondaryText)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var listenControl: some View {
        Button {
            store.begin(
                .live,
                captionsEnabled: store.listeningCaptionsEnabled,
                voiceLiftEnabled: store.voiceLiftEnabled
            )
        } label: {
            ZStack {
                Circle()
                    .stroke(ClearCueTheme.ink.opacity(0.12), lineWidth: 2)
                    .frame(width: 272, height: 272)
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.04 : 0.97))
                    .opacity(reduceMotion ? 0.35 : (pulse ? 0.2 : 0.55))

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, ClearCueTheme.mint.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 246, height: 246)
                    .shadow(color: ClearCueTheme.ink.opacity(0.13), radius: 28, y: 15)

                Image("MochiMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 198, height: 198)
                    .offset(y: 6)

                Text(listenLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(ClearCueTheme.ink, in: Capsule())
                    .offset(y: 100)

                if !canStart {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 246, height: 246)
                    if store.listeningCaptionsEnabled && !store.isHearingReady && store.captionEngine != .openAIRealtime {
                        ProgressView()
                            .tint(ClearCueTheme.ink)
                            .scaleEffect(1.2)
                    }
                }
            }
            .frame(width: 282, height: 282)
        }
        .buttonStyle(AssistListenButtonStyle())
        .disabled(!canStart)
        .accessibilityLabel("Start listening")
        .accessibilityHint("Starts recorded listening with your selected assistance tools")
    }

    private var welcome: some View {
        VStack(spacing: 6) {
            Text("Ready when you are.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(ClearCueTheme.text)
            Text(welcomeDetail)
                .font(.subheadline)
                .foregroundStyle(ClearCueTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var featureControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                featureIcon("captions.bubble.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Live captions")
                        .font(.subheadline.weight(.bold))
                    Text(captionDetail)
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Toggle("Live captions", isOn: $store.listeningCaptionsEnabled)
                    .labelsHidden()
                    .tint(ClearCueTheme.ink)
            }
            .padding(15)

            Divider().padding(.leading, 64)

            VStack(spacing: 11) {
                HStack(spacing: 13) {
                    featureIcon("headphones")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Lift")
                            .font(.subheadline.weight(.bold))
                        Text("Hear nearby voices more clearly")
                            .font(.caption)
                            .foregroundStyle(ClearCueTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Toggle("Voice Lift", isOn: $store.voiceLiftEnabled)
                        .labelsHidden()
                        .tint(ClearCueTheme.ink)
                }

                if store.voiceLiftEnabled {
                    HStack(spacing: 10) {
                        Text("Lift")
                        Slider(value: $store.voiceLiftGainDB, in: 3...9, step: 3)
                            .tint(ClearCueTheme.ink)
                        Text(liftLabel)
                            .foregroundStyle(ClearCueTheme.ink)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(15)
        }
        .foregroundStyle(ClearCueTheme.text)
        .background(ClearCueTheme.surface.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(ClearCueTheme.divider.opacity(0.7)))
        .animation(.snappy(duration: 0.24), value: store.voiceLiftEnabled)
    }

    private func featureIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(ClearCueTheme.ink)
            .frame(width: 38, height: 38)
            .background(ClearCueTheme.mint, in: Circle())
    }

    private var hearingTools: some View {
        DisclosureGroup(isExpanded: $showHearingTools) {
            CompactHearingTools(service: store.audiogramService)
                .padding(.top, 14)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "ear.badge.checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ClearCueTheme.ink)
                    .frame(width: 34, height: 34)
                    .background(ClearCueTheme.softMint, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hearing tools")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ClearCueTheme.text)
                    Text("Apple Health and Live Listen")
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
            }
        }
        .tint(ClearCueTheme.ink)
        .padding(16)
        .background(ClearCueTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ClearCueTheme.divider.opacity(0.6)))
    }

    private var canStart: Bool {
        store.voiceLiftEnabled || (
            store.listeningCaptionsEnabled &&
            (store.captionEngine == .openAIRealtime || store.isHearingReady)
        )
    }

    private var listenLabel: String {
        if !store.listeningCaptionsEnabled && !store.voiceLiftEnabled { return "Choose a tool" }
        if store.listeningCaptionsEnabled && !store.isHearingReady && store.captionEngine != .openAIRealtime { return "Getting ready…" }
        return "Listen"
    }

    private var welcomeDetail: String {
        switch (store.listeningCaptionsEnabled, store.voiceLiftEnabled) {
        case (true, true): "Tap Mochi for live captions and Voice Lift."
        case (true, false): "Tap Mochi to begin recorded listening with live captions."
        case (false, true): "Tap Mochi to lift nearby voices into your headphones."
        case (false, false): "Choose an assistance tool below to begin."
        }
    }

    private var captionDetail: String {
        if !store.isHearingReady && store.captionEngine != .openAIRealtime { return "Preparing on-device captions…" }
        return store.captionEngine == .openAIRealtime
            ? "Realtime · Whisper backup ready"
            : "Multilingual captions on this device"
    }

    private var liftLabel: String {
        if store.voiceLiftGainDB <= 3 { return "Low" }
        if store.voiceLiftGainDB <= 6 { return "Medium" }
        return "High"
    }
}

private struct CompactHearingTools: View {
    @ObservedObject var service: AudiogramService

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Task { await service.requestLatestAudiogram() }
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "waveform.path.ecg")
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health audiogram")
                            .font(.subheadline.weight(.semibold))
                        Text(audiogramStatus)
                            .font(.caption)
                            .foregroundStyle(ClearCueTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    if service.isLoading {
                        ProgressView()
                    } else {
                        Text("Check")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ClearCueTheme.ink)
                    }
                }
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .disabled(service.isLoading)

            Divider()

            Link(destination: URL(string: "https://support.apple.com/102479")!) {
                HStack(spacing: 11) {
                    Image(systemName: "apple.logo")
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Live Listen")
                            .font(.subheadline.weight(.semibold))
                        Text("Supported AirPods and Beats")
                            .font(.caption)
                            .foregroundStyle(ClearCueTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .padding(.vertical, 9)
            }

            Text("Mochi does not turn hearing-test thresholds into gain. Voice Lift is not a hearing aid.")
                .font(.caption2)
                .foregroundStyle(ClearCueTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
        .foregroundStyle(ClearCueTheme.text)
    }

    private var audiogramStatus: String {
        if let date = service.latestDate {
            return "Latest test \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return service.message
    }
}

private struct AssistListenButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}
