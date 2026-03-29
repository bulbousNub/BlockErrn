import SwiftUI

enum FlexErrnTheme {
    static let backgroundGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.12, green: 0.22, blue: 0.48),
            Color(red: 0.0, green: 0.40, blue: 0.64)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardShadowColor = Color.black.opacity(0.25)
    static let heroGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.28, green: 0.45, blue: 0.78),
            Color(red: 0.12, green: 0.30, blue: 0.58)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct FlexErrnCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: FlexErrnTheme.cardShadowColor, radius: 20, x: 0, y: 10)
    }
}

extension View {
    func flexErrnCardStyle() -> some View {
        modifier(FlexErrnCardModifier())
    }
}
