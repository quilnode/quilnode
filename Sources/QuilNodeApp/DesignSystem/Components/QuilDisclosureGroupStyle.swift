import SwiftUI

/// A disclosure control should behave like the row it visually occupies.
///
/// SwiftUI's compact macOS disclosure affordance can leave much of a custom
/// card header outside the hit region. This style keeps the familiar chevron,
/// while making the complete 44-point header row clickable, hoverable,
/// keyboard-focusable, and accessible. Applying it through `quilThemed(_:)`
/// gives every current and future `DisclosureGroup` the same interaction
/// contract without duplicating gesture code in feature views.
struct QuilDisclosureGroupStyle: DisclosureGroupStyle {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            QuilDisclosureHeader(
                isExpanded: configuration.isExpanded,
                theme: theme
            ) {
                withAnimation(motion.disclosure) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                configuration.label
            }

            if configuration.isExpanded {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(motion.revealTransition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

private struct QuilDisclosureHeader<Label: View>: View {
    let isExpanded: Bool
    let theme: QuilTheme
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovered = false
    @Environment(\.quilMotion) private var motion

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isHovered ? theme.colors.accent : theme.colors.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 28, height: 28)
                    .background(
                        theme.colors.selection.opacity(isHovered ? 0.72 : 0.38),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .accessibilityHidden(true)
                    .animation(motion.selection, value: isExpanded)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(
            QuilDisclosureHeaderButtonStyle(
                theme: theme,
                isHovered: isHovered
            )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(motion.hover, value: isHovered)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Collapse this section" : "Expand this section")
    }
}

private struct QuilDisclosureHeaderButtonStyle: ButtonStyle {
    @Environment(\.quilMotion) private var motion
    let theme: QuilTheme
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(theme.colors.primaryText)
            .background(
                theme.colors.selection.opacity(
                    configuration.isPressed ? 0.48 : (isHovered ? 0.24 : 0)
                ),
                in: RoundedRectangle(
                    cornerRadius: theme.metrics.navigationCornerRadius,
                    style: .continuous
                )
            )
            .scaleEffect(configuration.isPressed ? 0.997 : 1)
            .animation(motion.press, value: configuration.isPressed)
    }
}
