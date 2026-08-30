import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// The dashboard navigation owns layout only. Screen content and routing stay
/// in `DashboardView`, while every visual decision comes from `QuilTheme`.
struct DashboardSidebar: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @EnvironmentObject private var privacyMode: PrivacyModeController
    @State private var isToggleHovered = false
    @State private var hoveredDestination: DashboardDestination?
    @Binding var destination: DashboardDestination
    @Binding var isCollapsed: Bool
    let snapshot: NodeSnapshot
    let observationPhase: NodeObservationPhase
    var onSelectDestination: (DashboardDestination) -> Void = { _ in }

    private var width: CGFloat {
        isCollapsed ? theme.metrics.sidebarCollapsedWidth : theme.metrics.sidebarExpandedWidth
    }

    private var observation: NodeObservationPresentation {
        NodeObservationPresentation(phase: observationPhase, snapshot: snapshot)
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
            navigation
            Spacer(minLength: 0)
            utilities
            status
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
    private var utilities: some View {
        if isCollapsed {
            VStack(spacing: 0) {
                ThemePickerButton(
                    compact: true,
                    controlHeight: 40,
                    popoverEdge: .trailing,
                    embedded: true
                )
                utilityDivider(width: 22)
                ThemeAppearanceControl(compact: true, embedded: true)
                utilityDivider(width: 22)
                PrivacyModeButton(
                    isEnabled: $privacyMode.isEnabled,
                    compact: true,
                    controlHeight: 40,
                    embedded: true
                )
            }
            .frame(width: 40)
            .background(utilitySurface)
            .overlay(utilityBorder)
            .frame(maxWidth: .infinity, alignment: .center)
            .sidebarSection(inset: railInset)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                Text("DISPLAY")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(theme.colors.secondaryText.opacity(0.78))
                    .padding(.leading, 2)

                VStack(spacing: 0) {
                    ThemePickerButton(
                        compact: false,
                        fillsWidth: true,
                        controlHeight: 44,
                        popoverEdge: .trailing,
                        embedded: true,
                        showChevron: true
                    )
                    utilityDivider()
                    ThemeAppearanceControl(compact: false, embedded: true)
                    utilityDivider()
                    PrivacyModeButton(
                        isEnabled: $privacyMode.isEnabled,
                        compact: false,
                        fillsWidth: true,
                        controlHeight: 44,
                        embedded: true
                    )
                }
                .background(utilitySurface)
                .overlay(utilityBorder)
            }
            .sidebarSection(inset: railInset)
        }
    }

    private func utilityDivider(width: CGFloat? = nil) -> some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.42))
            .frame(width: width, height: max(theme.metrics.borderWidth, 0.5))
            .frame(maxWidth: width == nil ? .infinity : nil)
            .accessibilityHidden(true)
    }

    private var utilitySurface: some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .fill(theme.colors.surfaceElevated.opacity(0.78))
    }

    private var utilityBorder: some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .strokeBorder(theme.colors.border.opacity(0.5), lineWidth: max(theme.metrics.borderWidth, 0.5))
            .allowsHitTesting(false)
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

    private var navigation: some View {
        VStack(spacing: isCollapsed ? 6 : 4) {
            ForEach(DashboardDestination.allCases) { item in
                Button {
                    destination = item
                    onSelectDestination(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 13 * theme.components.iconScale, weight: .semibold))
                            .frame(width: 18)
                        if !isCollapsed {
                            Text(item.title)
                                .font(.subheadline.weight(destination == item ? .semibold : .regular))
                            Spacer(minLength: 0)
                        }
                    }
                    .foregroundStyle(
                        destination == item
                            ? railAccent
                            : theme.colors.primaryText.opacity(hoveredDestination == item ? 0.94 : 0.76)
                    )
                    .padding(.horizontal, isCollapsed ? 0 : 11)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: isCollapsed
                            ? theme.metrics.navigationRowHeight
                            : max(36, theme.metrics.navigationRowHeight - 4)
                    )
                    .contentShape(Rectangle())
                    .background { navigationSelection(for: item) }
                }
                .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.88, pressedScale: 0.995))
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onHover { hovered in
                    if hovered {
                        hoveredDestination = item
                    } else if hoveredDestination == item {
                        hoveredDestination = nil
                    }
                }
                .help(item.title)
                .accessibilityLabel(item.title)
            }
        }
        .sidebarSection(inset: railInset)
        .animation(motion.hover, value: hoveredDestination)
        .animation(motion.selection, value: destination)
    }

    @ViewBuilder
    private func navigationSelection(for item: DashboardDestination) -> some View {
        if destination == item {
            let shape = RoundedRectangle(
                cornerRadius: theme.components.navigationSelection == .capsule
                    ? theme.metrics.navigationRowHeight / 2
                    : theme.metrics.navigationCornerRadius,
                style: .continuous
            )
            switch theme.components.navigationSelection {
            case .row, .capsule:
                shape
                    .fill(theme.colors.selection.opacity(theme.components.selectionFillAlpha))
                    .overlay(
                        shape.strokeBorder(
                            railAccent.opacity(0.56), lineWidth: theme.components.selectedBorderWidth))
            case .icon:
                HStack {
                    RoundedRectangle(cornerRadius: theme.metrics.navigationCornerRadius, style: .continuous)
                        .fill(theme.colors.selection.opacity(theme.components.selectionFillAlpha))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.metrics.navigationCornerRadius, style: .continuous)
                                .strokeBorder(
                                    railAccent.opacity(0.58), lineWidth: theme.components.selectedBorderWidth)
                        )
                        .frame(width: 40)
                    Spacer(minLength: 0)
                }
            }
        } else if hoveredDestination == item {
            RoundedRectangle(
                cornerRadius: theme.metrics.navigationCornerRadius,
                style: .continuous
            )
            .fill(theme.colors.selection.opacity(0.32))
        }
    }

    @ViewBuilder
    private var status: some View {
        if isCollapsed {
            VStack(spacing: 5) {
                Circle()
                    .fill(healthTint)
                    .frame(width: 9, height: 9)
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                Text(observation.hasLiveTelemetry ? "\(snapshot.peers)" : "…")
                    .font(.caption2.bold().monospacedDigit())
                    .quilLiveValueTransition(value: snapshot.peers)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                theme.colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            )
            .sidebarSection(inset: railInset)
            .padding(.bottom, 10)
            .help(
                !observation.hasLiveTelemetry
                    ? observation.accessibilityStatus
                    : "\(snapshot.health.label) · \(privacySafeStatusDetail) · \(snapshot.peers) peers"
            )
            .accessibilityLabel(
                observation.hasLiveTelemetry
                    ? "\(snapshot.health.label), \(snapshot.peers) peers" : observation.accessibilityStatus)
        } else {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(healthTint)
                        .frame(width: 7, height: 7)
                    Text(observation.hasLiveTelemetry ? snapshot.health.label : observation.headerState)
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                }
                statusDetailView
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Label(observation.value("\(snapshot.peers)"), systemImage: "point.3.connected.trianglepath.dotted")
                    Spacer(minLength: 0)
                    Text(snapshot.version ?? "Local")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(12)
            .background(
                theme.colors.surfaceElevated,
                in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            )
            .sidebarSection(inset: railInset)
            .padding(.bottom, 10)
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

    private var healthTint: Color {
        if !observation.hasLiveTelemetry {
            return observationPhase == .loadingTelemetry && snapshot.isRunning
                ? theme.colors.success
                : theme.colors.info
        }
        return theme.colors.health(snapshot.health)
    }

    @ViewBuilder
    private var statusDetailView: some View {
        if observationPhase == .checkingProcess {
            Text("Reading managed service state")
        } else if observationPhase == .loadingTelemetry {
            Text(snapshot.isRunning ? "Loading live telemetry" : "Managed service is stopped")
        } else if snapshot.activeShards > 0 {
            PrivacyProtectedPhrase(
                value: String(snapshot.activeShards),
                suffix: " shards active · \(rewardLabel)",
                field: .activeShardCount
            )
        } else if snapshot.pendingJoins > 0 {
            PrivacyProtectedPhrase(
                value: String(snapshot.pendingJoins),
                suffix: " allocations joining",
                field: .allocationCount
            )
        } else {
            Text(snapshot.isRunning ? "Connected and waiting for work" : "Local service is stopped")
        }
    }

    private var privacySafeStatusDetail: String {
        if observationPhase == .checkingProcess { return "Reading managed service state" }
        if observationPhase == .loadingTelemetry {
            return snapshot.isRunning ? "Loading live telemetry" : "Managed service is stopped"
        }
        if snapshot.activeShards > 0 {
            let value = privacyMode.isEnabled ? "Hidden" : String(snapshot.activeShards)
            return value + " shards active · " + rewardLabel
        }
        if snapshot.pendingJoins > 0 {
            let value = privacyMode.isEnabled ? "Hidden" : String(snapshot.pendingJoins)
            return value + " allocations joining"
        }
        return snapshot.isRunning ? "Connected and waiting for work" : "Local service is stopped"
    }

    private var rewardLabel: String {
        snapshot.lastRewardCreditFrame == nil ? "rewards pending" : "rewards credited"
    }
}
