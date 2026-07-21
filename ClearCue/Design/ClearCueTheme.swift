import SwiftUI

enum ClearCueTheme {
    static let canvas = Color(light: 0xF6F5EF, dark: 0x101513)
    static let surface = Color(light: 0xFFFFFF, dark: 0x18201D)
    static let ink = Color(light: 0x12362E, dark: 0xB9F6E4)
    static let text = Color(light: 0x17211E, dark: 0xF2F7F5)
    static let secondaryText = Color(light: 0x5E6B67, dark: 0xA7B4B0)
    static let mint = Color(light: 0xC9F2E4, dark: 0x214C40)
    static let amber = Color(light: 0xFFF0C8, dark: 0x5A4215)
    static let amberStrong = Color(light: 0xA65A00, dark: 0xFFD27A)
    static let blue = Color(light: 0xDDEBFF, dark: 0x203B61)
    static let lilac = Color(light: 0xEEE6FF, dark: 0x3A2D58)
    static let danger = Color(light: 0xA33232, dark: 0xFF9D9D)
    static let divider = Color(light: 0xD8DFDC, dark: 0x34413D)
    static let softMint = Color(light: 0xEAF8F3, dark: 0x183029)
}

struct MochiWordmark: View {
    var size: CGFloat = 30

    var body: some View {
        Text("Mochi")
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(-1.8)
            .foregroundStyle(ClearCueTheme.ink)
            .shadow(color: ClearCueTheme.mint.opacity(0.9), radius: 0, x: 1.5, y: 2)
            .accessibilityAddTraits(.isHeader)
    }
}

extension Color {
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct ClearCueCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(ClearCueTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ClearCueTheme.divider.opacity(0.65), lineWidth: 1)
            }
    }
}

extension View {
    func clearCueCard() -> some View {
        modifier(ClearCueCardModifier())
    }

    func mochiScreenBackground() -> some View {
        background {
            LinearGradient(
                colors: [ClearCueTheme.softMint.opacity(0.82), ClearCueTheme.canvas],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }
}

struct MochiTopBar<Accessory: View>: View {
    var wordmarkSize: CGFloat = 31
    @ViewBuilder let accessory: Accessory

    init(wordmarkSize: CGFloat = 31, @ViewBuilder accessory: () -> Accessory) {
        self.wordmarkSize = wordmarkSize
        self.accessory = accessory()
    }

    var body: some View {
        HStack {
            MochiWordmark(size: wordmarkSize)
            Spacer()
            accessory
        }
    }
}

struct MochiHero: View {
    let title: String
    let subtitle: String
    var mascotSize: CGFloat = 92

    var body: some View {
        HStack(spacing: 16) {
            Image("MochiMascot")
                .resizable()
                .scaledToFit()
                .frame(width: mascotSize, height: mascotSize)
                .padding(5)
                .background(ClearCueTheme.mint.opacity(0.65), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(ClearCueTheme.text)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(ClearCueTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MochiSectionTitle: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ClearCueTheme.text)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClearCueTheme.secondaryText)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 56)
            .padding(.horizontal, 20)
            .foregroundStyle(Color.white)
            .background(ClearCueTheme.ink.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .shadow(color: ClearCueTheme.ink.opacity(configuration.isPressed ? 0.05 : 0.16), radius: 16, y: 8)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(minHeight: 48)
            .padding(.horizontal, 18)
            .foregroundStyle(ClearCueTheme.ink)
            .background(ClearCueTheme.mint.opacity(configuration.isPressed ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
