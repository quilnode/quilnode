import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var updateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            updateCenterHeader
            updateSummaryBand(availableUpdateSnapshot)

            if let checkProgress = releaseChecker.releaseCheckProgress {
                releaseCheckProgressCard(checkProgress)
            }

            if let snapshot = availableUpdateSnapshot {
                updateChannelMatrix(snapshot)
                managedQClientStrip(snapshot)
            } else if releaseChecker.releaseCheckProgress == nil {
                updateDiscoveryState
            }

            if let progress = releaseChecker.progress {
                updateProgressCard(progress)
            } else {
                updateFlightPlanIdle
            }

            updateMessageStrip
            updateHistoryStrip
        }
        .sheet(item: $pendingUpdatePolicy) { policy in
            OperatorInterlockView(
                model: OperatorInterlockPresentation.updatePolicy(policy),
                onCancel: { pendingUpdatePolicy = nil },
                onConfirm: { decision in
                    pendingUpdatePolicy = nil
                    releaseChecker.setPolicy(policy, updateNow: decision.id == "now")
                }
            )
            .quilThemed(theme)
        }
    }

    private var availableUpdateSnapshot: UpdateCenterSnapshot? {
        guard case let .available(snapshot) = releaseChecker.state else { return nil }
        return snapshot
    }

    private var updateDiscoveryState: some View {
        HStack(spacing: 14) {
            DashboardCircleIcon(systemImage: updateCenterIcon, tint: updateCenterTint, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(updateCenterTitle)
                    .font(.subheadline.weight(.semibold))
                Text(updateCenterDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if releaseChecker.state == .notChecked {
                Button("Check channels") { releaseChecker.requestCheck() }
                    .buttonStyle(.borderedProminent)
            } else if releaseChecker.lastError != nil {
                Button("Retry") { releaseChecker.requestCheck() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .controlSurface(tint: updateCenterTint)
    }

    @ViewBuilder
    private var updateMessageStrip: some View {
        if let message = releaseChecker.lastMessage {
            Label(
                PrivacySanitizer.display(message, enabled: privacyModeEnabled),
                systemImage: "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(theme.colors.success)
            .padding(.horizontal, 4)
        }
        if let error = releaseChecker.lastError {
            Label(
                PrivacySanitizer.display(error, enabled: privacyModeEnabled),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(theme.colors.danger)
            .textSelection(.enabled)
            .padding(.horizontal, 4)
        }
    }

    private var updateHistoryStrip: some View {
        HStack(spacing: 14) {
            if let event = releaseChecker.history.first {
                Label("Last update", systemImage: "clock.arrow.circlepath")
                Text(
                    "\(event.result.capitalized) · \(event.version) · \(event.timestamp.formatted(date: .abbreviated, time: .standard))"
                )
                if let commit = event.commit {
                    Text(shortCommit(commit)).monospaced()
                }
                Divider().frame(height: 14)
            }
            Text(updatePolicyFootnote)
                .lineLimit(2)
            Spacer()
            if releaseChecker.policy != .manual {
                Button("Run selected channel now") {
                    releaseChecker.requestAutomaticCheck()
                }
                .buttonStyle(.borderless)
                .disabled(releaseChecker.isWorking)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}
