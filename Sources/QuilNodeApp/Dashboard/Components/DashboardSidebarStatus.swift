import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Presents node evidence at the bottom of the rail. Privacy masking is kept
/// next to the values it protects so collapsed tooltips cannot bypass it.
struct DashboardSidebarStatus: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var privacyMode: PrivacyModeController
    let snapshot: NodeSnapshot
    let observationPhase: NodeObservationPhase
    let isCollapsed: Bool
    let railInset: CGFloat

    private var observation: NodeObservationPresentation {
        NodeObservationPresentation(phase: observationPhase, snapshot: snapshot)
    }

    @ViewBuilder
    var body: some View {
        if isCollapsed {
            compactStatus
        } else {
            expandedStatus
        }
    }

    private var compactStatus: some View {
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
                : "\(snapshot.health.label) · \(privacySafeDetail) · \(snapshot.peers) peers"
        )
        .accessibilityLabel(
            observation.hasLiveTelemetry
                ? "\(snapshot.health.label), \(snapshot.peers) peers" : observation.accessibilityStatus)
    }

    private var expandedStatus: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Circle()
                    .fill(healthTint)
                    .frame(width: 7, height: 7)
                Text(observation.hasLiveTelemetry ? snapshot.health.label : observation.headerState)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
            }
            detailView
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

    private var healthTint: Color {
        if !observation.hasLiveTelemetry {
            return observationPhase == .loadingTelemetry && snapshot.isRunning
                ? theme.colors.success
                : theme.colors.info
        }
        return theme.colors.health(snapshot.health)
    }

    @ViewBuilder
    private var detailView: some View {
        if observationPhase == .checkingProcess {
            Text("Reading managed service state")
        } else if observationPhase == .loadingTelemetry {
            Text(snapshot.isRunning ? "Loading live telemetry" : "Managed service is stopped")
        } else if snapshot.activeAllocations > 0 {
            PrivacyProtectedPhrase(
                value: String(snapshot.activeAllocations),
                suffix: " allocations active · \(rewardLabel)",
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

    private var privacySafeDetail: String {
        if observationPhase == .checkingProcess { return "Reading managed service state" }
        if observationPhase == .loadingTelemetry {
            return snapshot.isRunning ? "Loading live telemetry" : "Managed service is stopped"
        }
        if snapshot.activeAllocations > 0 {
            let value = privacyMode.isEnabled ? "Hidden" : String(snapshot.activeAllocations)
            return value + " allocations active · " + rewardLabel
        }
        if snapshot.pendingJoins > 0 {
            let value = privacyMode.isEnabled ? "Hidden" : String(snapshot.pendingJoins)
            return value + " allocations joining"
        }
        return snapshot.isRunning ? "Connected and waiting for work" : "Local service is stopped"
    }

    private var rewardLabel: String {
        snapshot.lastRewardCreditFrame == nil ? "no credit observed" : "credit observed"
    }
}
