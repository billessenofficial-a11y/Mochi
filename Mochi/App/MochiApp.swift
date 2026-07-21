import SwiftUI

@main
struct MochiApp: App {
    @StateObject private var store = ConversationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(MochiTheme.ink)
                .preferredColorScheme(store.preferredColorScheme)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var store: ConversationStore
    // Version this key whenever the required on-device model changes so an
    // existing install cannot land on Home with the wrong model cache.
    @AppStorage("mochi.onboardingV3Complete") private var onboardingComplete = false

    private var bypassOnboarding: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding") ||
        ProcessInfo.processInfo.arguments.contains("-guidedDemoPreview") ||
        ProcessInfo.processInfo.arguments.contains("-livePreview")
    }

    var body: some View {
        ZStack {
            MochiTheme.canvas.ignoresSafeArea()

            if !onboardingComplete && !bypassOnboarding {
                OnboardingView {
                    onboardingComplete = true
                }
                .transition(.opacity)
            } else {
                routedContent
            }
        }
        .animation(.snappy(duration: 0.3), value: store.route)
        .animation(.snappy(duration: 0.35), value: onboardingComplete)
        .task(id: onboardingComplete) {
            guard (onboardingComplete || bypassOnboarding), !bypassOnboarding else { return }
            await store.prepareHearingModel()
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch store.route {
        case .home:
            MainTabView()
                .transition(.opacity)
        case .conversation:
            ConversationView()
                .transition(.opacity)
        case .recap:
            RecapView()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var store: ConversationStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            AssistHomeView()
                .tabItem {
                    Label("Assist", systemImage: "ear.badge.waveform")
                }
                .tag(AppTab.home)

            RecordingsView()
                .tabItem {
                    Label("Recordings", systemImage: "waveform.circle.fill")
                }
                .tag(AppTab.recordings)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.settings)
        }
        .onChange(of: store.selectedTab) { _, _ in store.selectionHaptic() }
    }
}
