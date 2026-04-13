import SwiftUI

enum AurelinePalette {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.06, blue: 0.10),
            Color(red: 0.09, green: 0.11, blue: 0.17),
            Color(red: 0.03, green: 0.04, blue: 0.07),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let card = Color(red: 0.11, green: 0.13, blue: 0.20)
    static let cardRaised = Color(red: 0.14, green: 0.16, blue: 0.25)
    static let stroke = Color.white.opacity(0.08)
    static let accent = Color(red: 0.85, green: 0.73, blue: 0.45)
    static let accentMuted = Color(red: 0.54, green: 0.46, blue: 0.30)
    static let positive = Color(red: 0.47, green: 0.76, blue: 0.63)
    static let caution = Color(red: 0.95, green: 0.72, blue: 0.43)
    static let negative = Color(red: 0.91, green: 0.50, blue: 0.48)
    static let secondaryText = Color.white.opacity(0.66)
}

struct AurelineCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AurelinePalette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(AurelinePalette.stroke, lineWidth: 1)
                    )
            )
    }
}

struct AurelinePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AurelinePalette.accent,
                                AurelinePalette.accentMuted,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .foregroundStyle(Color.black.opacity(0.86))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct AurelineSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AurelinePalette.cardRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AurelinePalette.stroke, lineWidth: 1)
                    )
            )
            .foregroundStyle(Color.white)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct AurelineBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }
}

extension View {
    func aurelineCard() -> some View {
        modifier(AurelineCardModifier())
    }

    func screenBackground() -> some View {
        background(AurelinePalette.background.ignoresSafeArea())
    }
}
