import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// The dashboard navigation owns layout only. Screen content and routing stay
/// in `DashboardView`, while every visual decision comes from `QuilTheme`.
struct DashboardSidebar: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @State private var isToggleHovered = false
    @Binding var destination: DashboardDestination
    @Binding var isCollapsed: Bool
    let snapshot: NodeSnapshot
    let observationPhase: NodeObservationPhase
    var onSelectDestination: (DashboardDestination) -> Void = { _ in }

    private var width: CGFloat {
        isCollapsed ? theme.metrics.sidebarCollapsedWidth : theme.metrics.sidebarExpandedWidth
    }

    private var railAccent: Color {
        theme.recipes.hero == .topology || theme.recipes.hero == .orbital
            ? theme.colors.info
            : theme.colors.accent
    }

    /// A single invariant for the rail: brand, navigation glyphs, status, and
    /// the collapse control all share this horizontal axis in either state.
    private var railInset: CGFloat {
        max(8, (theme.metrics.sidebarCollapsedWidth - 40) / 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16 * theme.metrics.spacingScale) {
            header
            DashboardSidebarNavigation(
                destination: $destination,
                isCollapsed: isCollapsed,
                railInset: railInset,
                accent: railAccent,
                onSelectDestination: onSelectDestination
            )
            Spacer(minLength: 0)
            DashboardSidebarUtilities(isCollapsed: isCollapsed, railInset: railInset)
            DashboardSidebarStatus(
                snapshot: snapshot,
                observationPhase: observationPhase,
                isCollapsed: isCollapsed,
                railInset: railInset
            )
        }
        .frame(width: width, alignment: .leading)
        .padding(.top, 18 * theme.metrics.spacingScale)
        .background {
            ZStack {
                if theme.components.surfaceTreatment == .material {
                    Rectangle().fill(.regularMaterial)
                }
                Rectangle().fill(theme.colors.sidebar.opacity(theme.components.elevatedOpacity))
            }
        }
        .clipped()
    }

    @ViewBuilder
    private var header: some View {
        if isCollapsed {
            // Do not wrap this in the expanded HStack. Even zero-width Spacers
            // retain HStack spacing and move the control off the rail axis.
            toggleButton
                .frame(maxWidth: .infinity, alignment: .center)
                .sidebarSection(inset: railInset)
        } else {
            HStack(spacing: 6) {
                expandedBrand
                    .transition(motion.revealTransition)
                Spacer(minLength: 0)
                toggleButton
            }
            .sidebarSection(inset: railInset)
        }
    }

    private var expandedBrand: some View {
        HStack(spacing: 7) {
            themedBrandMark(size: 36)
            brandCopy
                .fixedSize(horizontal: true, vertical: false)
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private var brandCopy: some View {
        switch theme.recipes.sidebarBrand {
        case .tile:
            VStack(alignment: .leading, spacing: 1) {
                Text("QuilNode").font(.headline)
                Text("Local console").font(.caption2).foregroundStyle(theme.colors.secondaryText)
            }
        case .wordmark:
            VStack(alignment: .leading, spacing: 1) {
                Text("QUILNODE")
                    .font(.system(size: 15 * theme.typography.scale, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                Text(DashboardCopy.Brand.localConsole)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(railAccent)
            }
        case .index:
            VStack(alignment: .leading, spacing: 1) {
                Text("Q // 0x0")
                    .font(.system(size: 15 * theme.typography.scale, weight: .black, design: .monospaced))
                    .tracking(0.7)
                Text("local index")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
    }

    private var toggleButton: some View {
        Button {
            withAnimation(motion.sidebar) {
                isCollapsed.toggle()
            }
        } label: {
            ZStack {
                if isCollapsed {
                    themedBrandMark(size: 29)
                        .opacity(isToggleHovered ? 0 : 1)
                        .scaleEffect(isToggleHovered ? 0.82 : 1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(railAccent)
                        .opacity(isToggleHovered ? 1 : 0)
                        .scaleEffect(isToggleHovered ? 1 : 0.72)
                } else {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
            .frame(width: isCollapsed ? 40 : 32, height: isCollapsed ? 40 : 32)
            .contentShape(Rectangle())
            .background(
                isCollapsed && isToggleHovered
                    ? railAccent.opacity(0.12)
                    : theme.colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: theme.metrics.navigationCornerRadius, style: .continuous)
            )
            .animation(motion.hover, value: isToggleHovered)
        }
        .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.9, pressedScale: 0.985))
        .contentShape(Rectangle())
        .onHover { isToggleHovered = $0 }
        .help(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
        .accessibilityLabel(isCollapsed ? "Expand sidebar" : "Collapse sidebar")
        .accessibilityIdentifier("quilnode-sidebar-toggle")
    }

    private func themedBrandMark(size: CGFloat) -> some View {
        ApplicationBrandMark(size: size, theme: theme)
    }

}
