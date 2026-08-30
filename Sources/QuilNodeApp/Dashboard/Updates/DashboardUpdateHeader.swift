import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var updateCenterHeader: some View {
        Group {
            if !dashboardLayoutClass.isWide {
                VStack(alignment: .leading, spacing: 12) {
                    updateCenterTitleBlock
                    updateCenterControls
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    updateCenterTitleBlock
                    Spacer(minLength: 16)
                    updateCenterControls
                }
            }
        }
    }

    private var updateCenterTitleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NODE OPERATIONS")
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(theme.colors.accent)
            Text("Node Update Center")
                .font(.largeTitle.weight(.bold))
            Text("Choose a trust channel, prepare without downtime, then activate behind a rollback guard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var updateCenterControls: some View {
        VStack(alignment: dashboardLayoutClass.isWide ? .trailing : .leading, spacing: 7) {
            HStack(spacing: 8) {
                policyPicker
                Button {
                    if releaseChecker.isChecking {
                        releaseChecker.cancelCheck()
                    } else {
                        releaseChecker.requestCheck()
                    }
                } label: {
                    Label(
                        releaseChecker.isChecking ? "Cancel" : "Refresh",
                        systemImage: releaseChecker.isChecking ? "xmark" : "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(releaseChecker.isInstalling)
            }
            Label(automaticScheduleDescription, systemImage: "clock.badge.checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var policyPicker: some View {
        Picker(
            "Automatic channel",
            selection: Binding(
                get: { releaseChecker.policy },
                set: { selection in
                    if selection == .manual {
                        releaseChecker.setPolicy(.manual)
                    } else {
                        pendingUpdatePolicy = selection
                    }
                }
            )
        ) {
            ForEach(NodeUpdatePolicy.allCases) { policy in
                Text(policy.title).tag(policy)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 148)
        .help("Automatic node-update policy")
    }

    func updateSummaryBand(_ snapshot: UpdateCenterSnapshot?) -> some View {
        Group {
            if !dashboardLayoutClass.isWide {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 2),
                    spacing: 0
                ) {
                    updateSummaryCells(snapshot)
                }
            } else {
                HStack(spacing: 0) {
                    updateSummaryCells(snapshot, includeDividers: true)
                }
            }
        }
        .padding(.vertical, 12)
        .controlSurface(tint: theme.colors.info)
    }

    @ViewBuilder
    private func updateSummaryCells(
        _ snapshot: UpdateCenterSnapshot?,
        includeDividers: Bool = false
    ) -> some View {
        updateSummaryCell(
            systemImage: "internaldrive.fill",
            tint: theme.colors.success,
            eyebrow: "INSTALLED RUNTIME",
            value: snapshot?.installed.build.version ?? monitor.snapshot.version ?? "Detecting…",
            detail: snapshot?.installed.build.commit.map(shortCommit) ?? "Local managed node"
        )
        if includeDividers { summaryDivider }
        updateSummaryCell(
            systemImage: "checkmark.shield.fill",
            tint: policyTint,
            eyebrow: "AUTOMATIC POLICY",
            value: releaseChecker.policy.title,
            detail: releaseChecker.policy == .manual ? "Manual installs" : automaticScheduleDescription
        )
        if includeDividers { summaryDivider }
        appUpdateSummaryCell
        if includeDividers { summaryDivider }
        updateSummaryCell(
            systemImage: releaseChecker.canRollback ? "arrow.uturn.backward.circle.fill" : "lock.shield",
            tint: releaseChecker.canRollback ? theme.colors.warning : theme.colors.success,
            eyebrow: "ROLLBACK GUARD",
            value: releaseChecker.canRollback ? "Available" : "Created at activation",
            detail: releaseChecker.canRollback ? "Previous runtime retained" : "No dormant rollback claimed"
        )
    }

    private var appUpdateSummaryCell: some View {
        HStack(spacing: 10) {
            DashboardCircleIcon(systemImage: "app.badge.checkmark", tint: theme.colors.accent, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text("APP BUILD")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("v\(appUpdates.currentVersion) (\(appUpdates.currentBuild))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                Text(appUpdates.phase.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button {
                appUpdates.checkNow()
            } label: {
                if appUpdates.phase == .checking {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Check app")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!appUpdates.canCheck || appUpdates.phase == .checking)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func updateSummaryCell(
        systemImage: String,
        tint: Color,
        eyebrow: String,
        value: String,
        detail: String
    ) -> some View {
        HStack(spacing: 10) {
            DashboardCircleIcon(systemImage: systemImage, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.16))
            .frame(width: 1, height: 56)
    }

    private var policyTint: Color {
        switch releaseChecker.policy {
        case .manual: .secondary
        case .signedStable: theme.colors.success
        case .approvedDevelopment: theme.colors.info
        case .bleedingEdge: theme.colors.warning
        }
    }

    func shortCommit(_ value: String) -> String {
        String(value.prefix(10))
    }
}
