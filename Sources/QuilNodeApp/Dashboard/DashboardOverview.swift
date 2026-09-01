import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var overviewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            overviewHero
            if chainProgress.state == .archiveRecovery {
                archiveRecoveryCard
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
            if networkReadiness.assessment.state == .reviewRouter
                || networkReadiness.assessment.state == .localConfigurationIssue
            {
                networkAttentionCard
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
            overviewEvidenceDeck
            if let selection = overviewMilestoneSelection {
                ProtocolMilestoneOverviewSpotlight(
                    selection: selection,
                    snapshot: monitor.snapshot,
                    onOpenActivity: {
                        destination = .activity
                    },
                    onDismiss: {
                        withAnimation(motion.disclosure) {
                            milestoneVisibility.dismissFromOverview(selection.milestone)
                        }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .transition(motion.revealTransition)
            }
            if let event = overviewOperatorPresentation.latestActivity {
                overviewLatestActivity(event)
            }
        }
    }

    var archiveRecoveryCard: some View {
        Button {
            destination = .diagnostics
        } label: {
            HStack(spacing: 13) {
                DashboardCircleIcon(
                    systemImage: "externaldrive.badge.timemachine",
                    tint: theme.colors.info,
                    size: 42
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Network recovery in progress")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colors.primaryText)
                    Text(
                        "Archives are reachable but shared state is still converging at frame \(effectiveFrame.grouped). Keep this node running—no restart or store wipe is recommended."
                    )
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 10)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("WAITING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(theme.colors.info)
                    Text("\(monitor.snapshot.archiveSourceValue) sources · \(monitor.snapshot.peers) peers")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.colors.accent)
            }
            .padding(15)
            .contentShape(Rectangle())
            .controlSurface(tint: theme.colors.info)
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: theme.colors.info)
        .accessibilityLabel("Network recovery in progress. No restart needed. Open Diagnostics for local evidence.")
    }

    var networkAttentionCard: some View {
        Button {
            destination = .network
        } label: {
            HStack(spacing: 12) {
                DashboardCircleIcon(
                    systemImage: networkReadiness.assessment.state == .localConfigurationIssue
                        ? "exclamationmark.arrow.triangle.2.circlepath"
                        : "wifi.exclamationmark",
                    tint: networkReadiness.assessment.state == .localConfigurationIssue
                        ? theme.colors.danger : theme.colors.warning,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(networkReadiness.assessment.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colors.primaryText)
                    Text("Open Network for a guided local and router check.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(theme.colors.accent)
            }
            .padding(14)
            .contentShape(Rectangle())
            .controlSurface(
                tint: networkReadiness.assessment.state == .localConfigurationIssue
                    ? theme.colors.danger : theme.colors.warning)
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(
            tint: networkReadiness.assessment.state == .localConfigurationIssue
                ? theme.colors.danger : theme.colors.warning
        )
        .accessibilityHint("Opens the network setup guide")
    }

    var overviewMilestoneSelection: ProtocolMilestonePresentationPolicy.OverviewSelection? {
        ProtocolMilestonePresentationPolicy.overviewSelection(
            from: releaseChecker.protocolMilestones,
            currentFrame: max(monitor.snapshot.frame, monitor.snapshot.lastReceivedFrame),
            observedMilestones: monitor.snapshot.observedProtocolMilestones ?? [:],
            dismissedEventIDs: milestoneVisibility.dismissedOverviewEventIDs
        )
    }

    var protocolMilestoneActivitySection: some View {
        ProtocolMilestoneActivitySection(
            milestones: releaseChecker.protocolMilestones,
            snapshot: monitor.snapshot,
            refreshError: releaseChecker.protocolMilestoneError,
            dismissedOverviewEventIDs: milestoneVisibility.dismissedOverviewEventIDs,
            onRestoreToOverview: { milestone in
                milestoneVisibility.restoreToOverview(milestone)
            }
        )
    }
}
