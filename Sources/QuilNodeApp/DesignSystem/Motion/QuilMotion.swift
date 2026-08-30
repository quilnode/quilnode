import SwiftUI

/// Semantic motion tokens for the entire app.
///
/// Feature views describe *why* something moves (disclosure, navigation,
/// hover, live data) instead of choosing curves and durations themselves.
/// This keeps motion consistent across themes, prevents nested animation
/// transactions, and gives Reduce Motion one authoritative enforcement point.
struct QuilMotion {
    let scale: Double
    let reduceMotion: Bool

    init(scale: Double = 1, reduceMotion: Bool = false) {
        self.scale = min(max(scale, 0), 2)
        self.reduceMotion = reduceMotion
    }

    /// Fast feedback that never changes layout or position.
    var hover: Animation? { curve(duration: 0.10) }
    var press: Animation? { curve(duration: 0.08) }

    /// A disclosure owns one short transaction for its indicator, reveal, and
    /// the minimum layout change needed to make room for its content.
    var disclosure: Animation? { curve(duration: 0.15) }

    /// Navigation content changes immediately. This token is only for local
    /// selection highlights and compact symbol feedback.
    var selection: Animation? { curve(duration: 0.14) }
    var symbol: Animation? { curve(duration: 0.14) }

    /// Sidebar width and its compact/expanded labels share one transaction at
    /// the collapse button—the caller must not add another implicit animation.
    var sidebar: Animation? { curve(duration: 0.20) }

    /// Small status and numeric changes may animate without moving the layout.
    var liveValue: Animation? { curve(duration: 0.16) }
    var progress: Animation? { curve(duration: 0.22) }

    /// Very slow compositor-only movement for decorative atmosphere. It never
    /// changes layout and disappears entirely when Reduce Motion is enabled.
    var atmosphere: Animation? {
        guard !reduceMotion, scale > 0.01 else { return nil }
        return .timingCurve(0.45, 0, 0.55, 1, duration: 5.2 * scale)
            .repeatForever(autoreverses: true)
    }

    /// Position-based reveal transitions caused the old double-slide/ghosting
    /// effect. Opacity preserves spatial context and remains acceptable when
    /// Reduce Motion is enabled because no view travels across the screen.
    var revealTransition: AnyTransition { .opacity }

    private func curve(duration: Double) -> Animation? {
        guard !reduceMotion, scale > 0.01 else { return nil }
        // A restrained ease-out reaches the user's requested state quickly,
        // then settles without bounce. It suits pointer-driven macOS controls.
        return .timingCurve(0.22, 1, 0.36, 1, duration: duration * scale)
    }
}

private struct QuilMotionEnvironmentKey: EnvironmentKey {
    static let defaultValue = QuilMotion()
}

extension EnvironmentValues {
    var quilMotion: QuilMotion {
        get { self[QuilMotionEnvironmentKey.self] }
        set { self[QuilMotionEnvironmentKey.self] = newValue }
    }
}

/// Local pressed feedback for custom plain buttons. Hover appearance remains
/// opt-in because noninteractive cards must never imply clickability.
struct QuilPressFeedbackButtonStyle: ButtonStyle {
    @Environment(\.quilMotion) private var motion
    var pressedOpacity: Double = 0.92
    var pressedScale: CGFloat = 0.997

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(motion.press, value: configuration.isPressed)
    }
}

/// Shared loading primitive. It intentionally relies on the native macOS
/// progress indicator rather than a perpetual custom shimmer, minimizing CPU
/// and GPU work while preserving a clear accessible loading state.
struct QuilLoadingIndicator: View {
    @Environment(\.quilTheme) private var theme
    let label: String
    var detail: String? = nil
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            ProgressView()
                .controlSize(compact ? .small : .regular)
                .tint(theme.colors.info)
                .frame(width: compact ? 18 : 32, height: compact ? 18 : 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(detail.map { "\(label). \($0)" } ?? label)
    }
}

private struct QuilLiveValueTransitionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.quilMotion) private var motion
    let value: Value

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(motion.liveValue, value: value)
    }
}

private struct QuilHoverSurfaceModifier: ViewModifier {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @State private var isHovered = false

    let tint: Color?
    let cornerRadius: CGFloat?

    func body(content: Content) -> some View {
        let resolvedTint = tint ?? theme.colors.accent
        let resolvedRadius = cornerRadius ?? theme.metrics.controlCornerRadius

        content
            .overlay {
                RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                    .strokeBorder(
                        resolvedTint.opacity(isHovered ? 0.26 : 0),
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
                    .allowsHitTesting(false)
            }
            .onHover { isHovered = $0 }
            .animation(motion.hover, value: isHovered)
    }
}

extension View {
    /// Use only for frequently changing numeric text. The transition is local
    /// to the glyphs, so surrounding cards and grids never reanimate.
    func quilLiveValueTransition<Value: Equatable>(value: Value) -> some View {
        modifier(QuilLiveValueTransitionModifier(value: value))
    }

    /// Nonmoving pointer affordance for card-like controls. It changes only a
    /// border's opacity, keeping text rasterization and layout completely stable.
    func quilHoverSurface(tint: Color? = nil, cornerRadius: CGFloat? = nil) -> some View {
        modifier(QuilHoverSurfaceModifier(tint: tint, cornerRadius: cornerRadius))
    }
}
