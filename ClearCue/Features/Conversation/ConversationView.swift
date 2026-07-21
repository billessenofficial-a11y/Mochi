import SwiftUI

struct ConversationView: View {
    @EnvironmentObject private var store: ConversationStore
    @State private var showEndConfirmation = false
    @State private var showSpeakers = false
    @State private var selectedSpeakerID: String?

    var body: some View {
        VStack(spacing: 0) {
            sessionHeader
            statusStrip
            transcript
            if let event = store.activeEvent, event.state == .new || event.state == .repairing {
                Group {
                    if event.type == .nameMention {
                        NameMentionBanner(event: event)
                    } else {
                        AttentionBanner(event: event)
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
            controls
        }
        .mochiScreenBackground()
        .sheet(isPresented: $store.showRepair) {
            if let event = store.activeEvent {
                RepairView(event: event)
            }
        }
        .fullScreenCover(isPresented: $store.showSpeakerCard) {
            if let event = store.activeEvent {
                SpeakerCardView(event: event)
            }
        }
        .sheet(isPresented: $store.showCatchUp) {
            CatchUpView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $store.showSettings) {
            ConversationPreferencesView()
        }
        .sheet(isPresented: $showSpeakers) {
            SpeakerEditorView(initialSpeakerID: selectedSpeakerID)
        }
        .confirmationDialog("End this conversation?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
            Button("End and create recap") { store.endConversation() }
            Button("Keep listening", role: .cancel) {}
        } message: {
            Text("Listening will stop immediately.")
        }
        .animation(.snappy, value: store.activeEvent)
    }

    private var sessionHeader: some View {
        VStack(spacing: 13) {
            MochiTopBar(wordmarkSize: 26) {
                Text(elapsedTime)
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
                    .foregroundStyle(ClearCueTheme.ink)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionModeLabel)
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(store.mode == .guidedDemo ? ClearCueTheme.amberStrong : ClearCueTheme.ink)
                    Text(sessionStateTitle)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(ClearCueTheme.text)
                }

                Spacer()

                if store.sessionCaptionsEnabled {
                    Button {
                        selectedSpeakerID = nil
                        showSpeakers = true
                        store.selectionHaptic()
                    } label: {
                        Label("Speakers", systemImage: "person.2.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(height: 42)
                            .background(ClearCueTheme.surface, in: Capsule())
                            .overlay(Capsule().stroke(ClearCueTheme.divider.opacity(0.7)))
                    }
                    .accessibilityLabel("Name speakers")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            if store.speechService.isPreparing {
                if let progress = store.speechService.preparationProgress {
                    ProgressView(value: progress)
                        .controlSize(.small)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            } else {
                Circle()
                    .fill(store.speechService.isListening ? Color.red : ClearCueTheme.secondaryText)
                    .frame(width: 9, height: 9)
            }
            Text(statusText)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
            Spacer()
            if !store.speechService.errorMessage.orEmpty.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ClearCueTheme.danger)
            } else if !store.speechService.isPreparing {
                MicrophoneLevelMeter(level: store.speechService.microphoneLevel)
            }
        }
        .font(.caption)
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(ClearCueTheme.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(ClearCueTheme.divider.opacity(0.65)))
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if store.activeSegments.isEmpty {
                        listeningPlaceholder
                    }

                    ForEach(store.activeSegments) { segment in
                        TranscriptRow(segment: segment, scale: store.captionScale) {
                            selectedSpeakerID = segment.speaker.id
                            showSpeakers = true
                            store.selectionHaptic()
                        }
                            .id(segment.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: store.activeSegments.last?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var listeningPlaceholder: some View {
        VStack(spacing: 15) {
            ZStack(alignment: .bottomTrailing) {
                Image("MochiMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .padding(7)
                    .background(ClearCueTheme.mint.opacity(0.68), in: Circle())

                Image(systemName: store.speechService.errorMessage == nil ? "waveform" : "exclamationmark.triangle.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(store.speechService.errorMessage == nil ? ClearCueTheme.ink : ClearCueTheme.danger)
                    .frame(width: 40, height: 40)
                    .background(ClearCueTheme.surface, in: Circle())
                    .overlay(Circle().stroke(ClearCueTheme.divider.opacity(0.7)))
                    .symbolEffect(.variableColor.iterative, isActive: store.status == .listening && store.speechService.errorMessage == nil)
            }

            VStack(spacing: 5) {
                Text(store.speechService.errorMessage == nil ? "I’m listening." : "Let’s fix that.")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ClearCueTheme.text)
                Text(placeholderText)
                    .font(.subheadline)
                    .foregroundStyle(ClearCueTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            if store.mode.capturesAudio, store.speechService.isListening {
                VStack(spacing: 8) {
                    MicrophoneLevelMeter(
                        level: store.speechService.microphoneLevel,
                        barWidth: 7,
                        maximumHeight: 28
                    )
                    Text(microphoneHint)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 54)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if store.sessionCaptionsEnabled {
                Button {
                    store.showCatchUp = true
                } label: {
                    Label("Catch me up", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .foregroundStyle(.white)
                        .background(ClearCueTheme.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }

            HStack(spacing: 12) {
                Button {
                    store.togglePause()
                } label: {
                    Label(store.status == .paused ? "Resume" : "Pause", systemImage: store.status == .paused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.bordered)
                .tint(ClearCueTheme.ink)
                .font(.headline)

                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(ClearCueTheme.danger)
                .font(.headline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(ClearCueTheme.surface.opacity(0.88))
    }

    private var elapsedTime: String {
        String(format: "%02d:%02d", store.elapsedSeconds / 60, store.elapsedSeconds % 60)
    }

    private var sessionStateTitle: String {
        if store.status == .finishing { return "Creating recap" }
        if store.status == .paused { return "Paused" }
        if store.mode.capturesAudio, store.speechService.isPreparing { return "Preparing" }
        if !store.sessionCaptionsEnabled { return "Voice Lift" }
        return "Listening"
    }

    private var statusText: String {
        if store.mode == .guidedDemo {
            return store.status == .listening ? "Simulated conversation running" : "Demo paused"
        }
        if store.status == .finishing { return "Saving audio and creating your title and recap…" }
        if let error = store.speechService.errorMessage { return error }
        return store.speechService.statusMessage
    }

    private var placeholderText: String {
        if store.mode == .guidedDemo { return "The simulated conversation is about to begin…" }
        if let error = store.speechService.errorMessage { return error }
        if !store.sessionCaptionsEnabled {
            return "Voice Lift is active. Keep the phone near the person speaking."
        }
        if store.speechService.isPreparing { return "Loading the on-device Whisper backup…" }
        return "Start speaking when everyone is ready."
    }

    private var microphoneHint: String {
        if let error = store.speechService.errorMessage {
            return store.sessionCaptionsEnabled
                ? "Recording continues locally; captions are unavailable"
                : error
        }
        guard store.speechService.isReceivingAudio else {
            return "Waiting for microphone audio…"
        }
        if store.speechService.microphoneLevel > 0.12 {
            return store.sessionCaptionsEnabled
                ? "Sound detected — captions are streaming"
                : "Sound detected — voices are being lifted"
        }
        return "Microphone active — speak close to the phone"
    }

    private var sessionModeLabel: String {
        switch store.mode {
        case .guidedDemo: "SIMULATED CONVERSATION"
        case .live: store.sessionVoiceLiftEnabled ? "LISTENING ASSISTANCE" : "HEARING LIVE"
        case .recording: "RECORDING"
        }
    }
}

private struct MicrophoneLevelMeter: View {
    let level: Float
    var barWidth: CGFloat = 4
    var maximumHeight: CGFloat = 16

    private let thresholds: [Float] = [0.04, 0.12, 0.24, 0.4, 0.62]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Image(systemName: "mic.fill")
                .font(.caption2)
                .foregroundStyle(ClearCueTheme.secondaryText)
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(thresholds.enumerated()), id: \.offset) { index, threshold in
                    Capsule()
                        .fill(level >= threshold ? ClearCueTheme.ink : ClearCueTheme.divider)
                        .frame(width: barWidth, height: maximumHeight * CGFloat(index + 1) / CGFloat(thresholds.count))
                }
            }
            .frame(height: maximumHeight)
        }
        .animation(.linear(duration: 0.08), value: level)
        .accessibilityLabel("Microphone input level")
        .accessibilityValue(level > 0.12 ? "Sound detected" : "Quiet")
    }
}

private struct TranscriptRow: View {
    let segment: TranscriptSegment
    let scale: Double
    let onSpeakerTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var namePulse = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            speakerMarker
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Button(action: onSpeakerTap) {
                        HStack(spacing: 4) {
                            Text(segment.speaker.displayName)
                                .font(.caption.weight(.bold))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Image(systemName: "pencil")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if let emphasis = segment.emphasis {
                        emphasisBadge(emphasis)
                    }
                    Text(segment.timestamp)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
                Text(segment.text)
                    .font(.system(size: 20 * scale, weight: segment.isFinal ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(segment.isFinal ? ClearCueTheme.text : ClearCueTheme.secondaryText)
                    .italic(!segment.isFinal)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if !segment.isFinal {
                    Text("Captioning…")
                        .font(.caption)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
            }
        }
        .padding(16)
        .background(
            segment.emphasis == .nameMention
                ? ClearCueTheme.mint.opacity(namePulse ? 0.95 : 0.58)
                : ClearCueTheme.surface,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: segment.emphasis == .nameMention ? 2 : 1)
        }
        .scaleEffect(segment.emphasis == .nameMention && namePulse ? 1.012 : 1)
        .shadow(
            color: segment.emphasis == .nameMention
                ? ClearCueTheme.ink.opacity(namePulse ? 0.17 : 0.07)
                : Color.black.opacity(0.025),
            radius: segment.emphasis == .nameMention ? 16 : 10,
            y: 4
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(segment.speaker.displayName), \(segment.timestamp): \(segment.text)\(segment.isFinal ? "" : ", partial caption")")
        .task(id: segment.id) {
            guard segment.emphasis == .nameMention, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.42).repeatCount(4, autoreverses: true)) {
                namePulse = true
            }
            try? await Task.sleep(for: .seconds(3.4))
            namePulse = false
        }
    }

    private var borderColor: Color {
        if segment.emphasis == .nameMention {
            return ClearCueTheme.ink.opacity(namePulse ? 0.72 : 0.35)
        }
        if segment.emphasis == .importantDetail { return ClearCueTheme.amberStrong.opacity(0.55) }
        return ClearCueTheme.divider.opacity(0.55)
    }

    private var speakerMarker: some View {
        ZStack {
            Circle().fill(backgroundColor)
            Image(systemName: segment.speaker.id == "user" ? "person.fill" : "person.wave.2.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(ClearCueTheme.text)
        }
        .frame(width: 34, height: 34)
        .overlay(Circle().stroke(ClearCueTheme.divider, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var backgroundColor: Color {
        switch segment.speaker.style {
        case .mint: ClearCueTheme.mint
        case .blue: ClearCueTheme.blue
        case .lilac: ClearCueTheme.lilac
        case .neutral: ClearCueTheme.surface
        }
    }

    private func emphasisBadge(_ emphasis: SegmentEmphasis) -> some View {
        let config: (String, String) = switch emphasis {
        case .nameMention: ("Your name", "person.crop.circle.badge.exclamationmark")
        case .question: ("Question", "questionmark.bubble.fill")
        case .importantDetail: ("Check detail", "exclamationmark.circle.fill")
        }
        return Label(config.0, systemImage: config.1)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ClearCueTheme.surface.opacity(0.8), in: Capsule())
    }
}

private struct NameMentionBanner: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let event: AttentionEvent
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(ClearCueTheme.ink.opacity(0.22), lineWidth: 2)
                    .frame(width: 46, height: 46)
                    .scaleEffect(reduceMotion ? 1 : (pulse ? 1.24 : 0.82))
                    .opacity(reduceMotion ? 0.5 : (pulse ? 0 : 0.8))
                Image(systemName: "person.crop.circle.badge.exclamationmark.fill")
                    .font(.title2)
                    .foregroundStyle(ClearCueTheme.ink)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(attentionTitle)
                    .font(.headline)
                    .foregroundStyle(ClearCueTheme.text)
                Text("Someone may be speaking directly to you.")
                    .font(.caption)
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }

            Spacer(minLength: 4)

            Button("Got it") {
                store.dismiss(event)
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(ClearCueTheme.ink)
        }
        .padding(15)
        .background(ClearCueTheme.mint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ClearCueTheme.ink.opacity(0.28), lineWidth: 1.5))
        .shadow(color: ClearCueTheme.ink.opacity(0.12), radius: 18, y: 8)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(attentionTitle). Someone may be speaking directly to you.")
    }

    private var attentionTitle: String {
        let name = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "That sounded like your name" : "\(name), that sounded like your name"
    }
}

private struct AttentionBanner: View {
    @EnvironmentObject private var store: ConversationStore
    let event: AttentionEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(.title2)
                    .foregroundStyle(ClearCueTheme.amberStrong)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.headline)
                    Text(event.explanation)
                        .font(.subheadline)
                        .foregroundStyle(ClearCueTheme.secondaryText)
                }
            }
            HStack(spacing: 10) {
                Button("Dismiss") { store.dismiss(event) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                Button("Clarify") { store.openRepair(event) }
                    .buttonStyle(.borderedProminent)
                    .tint(ClearCueTheme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(16)
        .background(ClearCueTheme.amber, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(ClearCueTheme.amberStrong.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Attention: \(event.title). \(event.explanation)")
    }
}

private struct ConversationPreferencesView: View {
    @EnvironmentObject private var store: ConversationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Caption size") {
                    Slider(value: $store.captionScale, in: 0.9...1.45, step: 0.05)
                }
                Section("Attention") {
                    Toggle("Haptic cues", isOn: $store.hapticsEnabled)
                }
            }
            .navigationTitle("Conversation display")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}
