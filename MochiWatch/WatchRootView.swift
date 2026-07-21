import SwiftUI
import WatchKit

struct WatchRootView: View {
    @EnvironmentObject private var session: WatchSessionModel
    @State private var showCatchUp = false
    @State private var showEndConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                MochiWatchTheme.canvas.ignoresSafeArea()

                Group {
                    switch session.state {
                    case .consent:
                        consentView
                    case .listening, .paused, .finishing:
                        activeView
                    case .complete:
                        completeView
                    case .ready:
                        readyView
                    }
                }
                .foregroundStyle(.white)
            }
            .sheet(isPresented: $showCatchUp) {
                WatchCatchUpView()
                    .environmentObject(session)
            }
            .confirmationDialog("End this conversation?", isPresented: $showEndConfirmation) {
                Button("End and create recap", role: .destructive) {
                    session.send("endConversation")
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var readyView: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(MochiWatchTheme.mint)
                    .frame(width: 72, height: 72)
                Image(systemName: "cat.fill")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(MochiWatchTheme.ink)
            }
            Text("Ready when you are")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Start on iPhone to confirm recording.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
            Button("Start listening") {
                session.send("requestStart")
            }
            .buttonStyle(.borderedProminent)
            .tint(MochiWatchTheme.mint)
            .foregroundStyle(MochiWatchTheme.ink)
            Spacer(minLength: 0)
            connectionMessage
        }
        .padding(.horizontal, 8)
    }

    private var consentView: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(MochiWatchTheme.ink)
            Text("Confirm on iPhone")
                .font(.headline)
            Text("Mochi waits for your explicit recording consent before listening.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    private var activeView: some View {
        ScrollView {
            VStack(spacing: 9) {
                HStack {
                    Label(session.state == .paused ? "Paused" : "Listening", systemImage: session.state == .paused ? "pause.fill" : "waveform")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(format(session.displayElapsed(at: context.date)))
                            .font(.caption2.monospacedDigit().weight(.semibold))
                    }
                }

                if !session.mentionID.isEmpty {
                    mentionCard
                }

                latestCaptionCard

                Button {
                    session.send("refreshCatchUp")
                    showCatchUp = true
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Label("Catch me up", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(MochiWatchTheme.ink)
                }
                .buttonStyle(.borderedProminent)
                .tint(MochiWatchTheme.mint)

                HStack(spacing: 7) {
                    Button {
                        session.send("togglePause")
                    } label: {
                        Image(systemName: session.state == .paused ? "play.fill" : "pause.fill")
                    }
                    .tint(.gray.opacity(0.34))

                    Button(role: .destructive) {
                        showEndConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .tint(.red)
                }

                connectionMessage
            }
            .padding(.horizontal, 2)
        }
    }

    private var mentionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Your name", systemImage: "person.wave.2.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(MochiWatchTheme.ink)
            Text(session.mentionText)
                .font(.body.weight(.semibold))
                .foregroundStyle(MochiWatchTheme.ink)
                .lineLimit(3)
            Button("Got it") {
                session.acknowledgeMention()
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(MochiWatchTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(MochiWatchTheme.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var latestCaptionCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.latestSpeaker.isEmpty ? "Waiting for speech" : session.latestSpeaker)
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                Spacer()
                Text(session.latestTimestamp)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(session.latestText.isEmpty ? "The latest caption will appear here." : session.latestText)
                .font(.body.weight(.semibold))
                .foregroundStyle(MochiWatchTheme.ink)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .foregroundStyle(MochiWatchTheme.ink)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var completeView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 42))
                .foregroundStyle(MochiWatchTheme.ink)
            Text("Recap is ready")
                .font(.headline)
            Text("Open Mochi on iPhone for playback, transcript, and chat.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .padding(12)
    }

    @ViewBuilder
    private var connectionMessage: some View {
        if let message = session.connectionMessage {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        }
    }

    private func format(_ total: Int) -> String {
        String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct WatchCatchUpView: View {
    @EnvironmentObject private var session: WatchSessionModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Catch up")
                        .font(.headline)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.caption)
                }

                Text(session.catchUpOverview)
                    .font(.body.weight(.semibold))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(MochiWatchTheme.ink)
                    .background(MochiWatchTheme.mint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if session.catchUpItems.isEmpty {
                    ProgressView("Finding what matters…")
                        .font(.caption)
                } else {
                    ForEach(session.catchUpItems) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Label(item.title, systemImage: icon(for: item.kind))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(item.kind == .needsYou ? .orange : MochiWatchTheme.ink)
                            Text(item.text)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(9)
                        .foregroundStyle(MochiWatchTheme.ink)
                        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .background(MochiWatchTheme.canvas.ignoresSafeArea())
    }

    private func icon(for kind: WatchCatchUpKind) -> String {
        switch kind {
        case .needsYou: "person.crop.circle.badge.exclamationmark"
        case .decision: "checkmark.seal.fill"
        case .action: "checklist"
        case .detail: "exclamationmark.circle.fill"
        case .recent: "clock.fill"
        }
    }
}
