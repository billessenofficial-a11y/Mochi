import SwiftUI

@main
struct MochiWatchApp: App {
    @StateObject private var session = WatchSessionModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(session)
                .tint(MochiWatchTheme.ink)
                .preferredColorScheme(.dark)
        }
    }
}
