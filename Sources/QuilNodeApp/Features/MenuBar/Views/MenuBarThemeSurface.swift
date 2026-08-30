import SwiftUI

extension View {
    /// Establishes one visual contract at the menu-window boundary so labels,
    /// controls, and the system-owned window container resolve the same theme
    /// as the dashboard. Child views only override semantic status colors.
    func menuBarThemeSurface() -> some View {
        modifier(MenuBarThemeSurfaceModifier())
    }
}

private struct MenuBarThemeSurfaceModifier: ViewModifier {
    @Environment(\.quilTheme) private var theme

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            themed(content)
                .containerBackground(for: .window) {
                    ThemeCanvasBackground().ignoresSafeArea()
                }
        } else {
            themed(content)
        }
    }

    private func themed(_ content: Content) -> some View {
        content
            .fontDesign(theme.typography.displayDesign)
            .foregroundStyle(theme.colors.primaryText)
            .background { ThemeCanvasBackground().ignoresSafeArea() }
    }
}
