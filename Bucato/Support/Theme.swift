import SwiftUI

/// Ink on paper. No accent colour, no tinted badges, no filled cards: the only
/// thing with a shape of its own is the care symbol itself.
enum Theme {
    static let ink = Color.primary
    static let muted = Color.secondary

    static let paper = Color(uiColor: .systemBackground)
    /// Barely-there fill for the few surfaces that need to sit apart from the page.
    static let well = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.10, alpha: 1) : UIColor(white: 0.965, alpha: 1)
    })
    static let hairline = Color.primary.opacity(0.12)

    static let danger = Color(uiColor: .systemRed)

    static let gutter: CGFloat = 20
    static let blockSpacing: CGFloat = 28
}

/// A section title: small, spaced out, quiet.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1 / UIScreen.main.scale)
    }
}

/// The one filled control in the app.
struct InkButtonStyle: ButtonStyle {
    var expands = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: expands ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, expands ? 0 : 22)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.ink.opacity(configuration.isPressed ? 0.7 : 1))
            )
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(configuration.isPressed ? 0.5 : 0.25), lineWidth: 1)
            )
    }
}

enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
