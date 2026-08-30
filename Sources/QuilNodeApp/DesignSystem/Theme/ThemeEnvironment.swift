import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

private struct QuilThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = QuilTheme.quilNode
}

extension EnvironmentValues {
    var quilTheme: QuilTheme {
        get { self[QuilThemeEnvironmentKey.self] }
        set { self[QuilThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    func quilThemed(_ theme: QuilTheme) -> some View {
        modifier(QuilThemedModifier(theme: theme))
    }

    func controlSurface(tint: Color? = nil) -> some View {
        modifier(QuilControlSurfaceModifier(tint: tint))
    }
}

private struct QuilThemedModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let theme: QuilTheme

    func body(content: Content) -> some View {
        content
            .environment(\.quilTheme, theme)
            .environment(
                \.quilMotion,
                QuilMotion(
                    scale: theme.components.motionScale,
                    reduceMotion: reduceMotion
                )
            )
            .tint(theme.colors.accent)
            .preferredColorScheme(theme.preferredColorScheme)
            .disclosureGroupStyle(QuilDisclosureGroupStyle())
    }
}

extension QuilTheme.Colors {
    func health(_ health: NodeHealth) -> Color {
        switch health {
        case .active: success
        case .joining: warning
        case .syncing: info
        case .stalled: warning
        case .stopped: danger
        }
    }
}

private struct QuilControlSurfaceModifier: ViewModifier {
    @Environment(\.quilTheme) private var theme
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if theme.components.surfaceTreatment == .material {
                        RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                            .fill(.thinMaterial)
                    }
                    RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                        .fill(theme.colors.surface.opacity(theme.components.surfaceOpacity))
                    if let tint {
                        RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                            .fill(tint.opacity(theme.components.heroAccentOpacity))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous)
                    .strokeBorder(
                        theme.colors.border.opacity(theme.components.borderOpacity),
                        style: StrokeStyle(
                            lineWidth: max(theme.metrics.borderWidth, 0.5),
                            lineCap: .butt,
                            dash: usesDashedBorder ? [5, 4] : []
                        )
                    )
            }
            .shadow(
                color: surfaceShadowColor,
                radius: theme.components.shadowStyle == .none ? 0 : (theme.components.shadowStyle == .glow ? 12 : 7),
                y: theme.components.shadowStyle == .soft ? 3 : 0
            )
    }

    private var panelCornerRadius: CGFloat {
        switch theme.recipes.panel {
        case .card: theme.metrics.controlCornerRadius
        case .ruled: 0
        case .terminal: min(theme.metrics.controlCornerRadius, 4)
        }
    }

    private var usesDashedBorder: Bool {
        theme.recipes.panel == .terminal || theme.components.surfaceBorderStyle == .dashed
    }

    private var surfaceShadowColor: Color {
        switch theme.components.shadowStyle {
        case .none: .clear
        case .soft: .black.opacity(theme.components.shadowOpacity)
        case .glow: (tint ?? theme.colors.accent).opacity(theme.components.shadowOpacity)
        }
    }
}

/// Shared dashboard atmosphere. It is intentionally rendered from bounded
/// tokens rather than theme-specific code, so local packs get the same depth
/// as bundled themes without becoming executable plugins.
struct ThemeCanvasBackground: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        ZStack {
            backdrop
            decoration
                .opacity(theme.components.decorationOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var backdrop: some View {
        switch theme.components.backdropStyle {
        case .solid:
            theme.colors.canvas
        case .gradient:
            LinearGradient(
                colors: [theme.colors.canvas, theme.colors.sidebar.opacity(0.94), theme.colors.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .spotlight:
            ZStack {
                theme.colors.canvas
                RadialGradient(
                    colors: [theme.colors.accent.opacity(0.17), theme.colors.accentSecondary.opacity(0.055), .clear],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: 680
                )
            }
        }
    }

    @ViewBuilder
    private var decoration: some View {
        switch theme.components.decorationStyle {
        case .none:
            Color.clear
        case .grid:
            ThemePatternCanvas(kind: .grid, color: theme.colors.accent)
        case .dots:
            ThemePatternCanvas(kind: .dots, color: theme.colors.accentSecondary)
        case .scanlines:
            ThemePatternCanvas(kind: .scanlines, color: theme.colors.primaryText)
        }
    }
}

private struct ThemePatternCanvas: View {
    enum Kind { case grid, dots, scanlines }
    let kind: Kind
    let color: Color

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            switch kind {
            case .grid:
                var path = Path()
                stride(from: 0.0, through: size.width, by: 32).forEach {
                    path.move(to: CGPoint(x: $0, y: 0))
                    path.addLine(to: CGPoint(x: $0, y: size.height))
                }
                stride(from: 0.0, through: size.height, by: 32).forEach {
                    path.move(to: CGPoint(x: 0, y: $0))
                    path.addLine(to: CGPoint(x: size.width, y: $0))
                }
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            case .dots:
                for x in stride(from: 8.0, through: size.width, by: 24) {
                    for y in stride(from: 8.0, through: size.height, by: 24) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(color))
                    }
                }
            case .scanlines:
                var path = Path()
                stride(from: 1.0, through: size.height, by: 5).forEach {
                    path.move(to: CGPoint(x: 0, y: $0))
                    path.addLine(to: CGPoint(x: size.width, y: $0))
                }
                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
    }
}
