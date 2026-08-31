import SwiftUI

/// Static atmosphere behind the overview. Uses existing theme tokens so
/// bundled and local themes share the same rendering and accessibility rules.
struct ThemeHeroBackground: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            theme.colors.canvas.opacity(0.84)
            if contrast != .increased {
                atmosphere
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var atmosphere: some View {
        switch theme.components.backdropStyle {
        case .solid:
            Color.clear
        case .gradient:
            LinearGradient(
                colors: [theme.colors.selection.opacity(0.65), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .spotlight:
            EllipticalGradient(
                colors: [theme.colors.selection.opacity(0.65), .clear],
                center: .topLeading, startRadiusFraction: 0, endRadiusFraction: 1
            )
        }
    }
}
