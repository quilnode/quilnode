import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    @ViewBuilder
    var destinationContent: some View {
        if destination.waitsForInitialTelemetry, !nodeObservation.hasLiveTelemetry {
            NodeObservationWaitingView(presentation: nodeObservation)
        } else {
            switch destination {
            case .overview:
                overviewSection
            case .activity:
                ActivityDashboardView(snapshot: monitor.snapshot)
                protocolMilestoneActivitySection
            case .network:
                NetworkReadinessView()
            case .identity:
                IdentityOverviewView(
                    snapshot: monitor.snapshot,
                    seniorityTrend: history.seniorityTrend(for: monitor.snapshot)
                ) {
                    destination = .recovery
                }
            case .recovery:
                IdentityRecoveryView()
            case .updates:
                updateSection
            case .diagnostics:
                DiagnosticsDashboardView { selectedDestination in
                    destination = selectedDestination
                    handleDestinationSelection(selectedDestination)
                }
            }
        }
    }

    var headerActions: some View {
        HStack(spacing: 15) {
            HStack(spacing: 6) {
                Circle()
                    .fill(headerStatusTint)
                    .frame(width: 6, height: 6)
                Text(headerStatusLabel)
                    .foregroundStyle(theme.colors.primaryText)
                Text(nodeObservation.headerState)
                    .foregroundStyle(theme.colors.secondaryText)
            }

            if let version = monitor.snapshot.version {
                Text(version)
                    .foregroundStyle(theme.colors.secondaryText)
            }

            Button {
                Task { await monitor.refresh(forceNodeInfo: true) }
            } label: {
                Group {
                    if monitor.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .background(
                    theme.colors.surfaceElevated.opacity(0.001),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.accent)
            .quilHoverSurface(tint: theme.colors.accent, cornerRadius: 7)
            .help("Refresh all local node information")
        }
        .font(.caption2.weight(.semibold))
        .frame(height: 28)
    }

    var headerStatusLabel: String {
        nodeObservation.headerScope
    }

    var headerStatusTint: Color {
        if monitor.observationPhase == .checkingProcess { return theme.colors.info }
        if monitor.observationPhase == .loadingTelemetry, monitor.snapshot.isRunning {
            return theme.colors.success
        }
        return monitor.snapshot.isRunning ? theme.colors.success : theme.colors.danger
    }

    var destinationIndex: Int {
        (DashboardDestination.allCases.firstIndex(of: destination) ?? 0) + 1
    }

}
