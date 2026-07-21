import SwiftUI

enum MochiWatchTheme {
    static let ink = Color(red: 0.035, green: 0.25, blue: 0.20)
    static let mint = Color(red: 0.73, green: 0.95, blue: 0.88)
    static let amber = Color(red: 1.0, green: 0.84, blue: 0.46)
    static let canvas = LinearGradient(
        colors: [
            Color.black,
            Color(red: 0.025, green: 0.16, blue: 0.13)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
