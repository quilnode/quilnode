import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var protocolAllocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Allocation lattice")
                    .font(.system(size: 13, weight: .semibold))
                Text("Workers, assigned shards and coverage")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer(minLength: 12)
                Button {
                    destination = .identity
                } label: {
                    Label("Manage allocations", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(theme.colors.info)
                .accessibilityHint("Opens Identity and allocation details")
            }

            HStack(spacing: 0) {
                ProtocolAllocationSummaryStat(
                    title: "Active",
                    value: nodeObservation.value(String(monitor.snapshot.activeShards)),
                    detail: "shard paths",
                    tint: monitor.snapshot.activeShards > 0 ? theme.colors.success : theme.colors.secondaryText,
                    privacyField: .activeShardCount
                )
                allocationSummaryDivider
                ProtocolAllocationSummaryStat(
                    title: "Joining",
                    value: nodeObservation.value(String(monitor.snapshot.pendingJoins)),
                    detail: "pending paths",
                    tint: monitor.snapshot.pendingJoins > 0 ? theme.colors.warning : theme.colors.secondaryText,
                    privacyField: .allocationCount
                )
                allocationSummaryDivider
                ProtocolAllocationSummaryStat(
                    title: "Capacity",
                    value: nodeObservation.value(localWorkerCapacity.map(String.init) ?? "—"),
                    detail: "local workers",
                    tint: theme.colors.info,
                    privacyField: .hardwareProfile
                )
                allocationSummaryDivider
                ProtocolAllocationSummaryStat(
                    title: "Coverage",
                    value: nodeObservation.value(localCoverageLabel),
                    detail: "assigned shards",
                    tint: localCoverageTint,
                    privacyField: .shardAllocation
                )
            }
            .frame(minHeight: 58)
            .background(theme.colors.surface.opacity(0.48))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(theme.colors.border.opacity(0.56), lineWidth: max(theme.metrics.borderWidth, 0.5))
            }

            if monitor.snapshot.shardAllocations.isEmpty,
                monitor.snapshot.totalAllocations > 0
            {
                ProtocolAggregateAllocationCell(
                    active: monitor.snapshot.activeShards,
                    joining: monitor.snapshot.pendingJoins,
                    total: monitor.snapshot.totalAllocations
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                    if monitor.snapshot.shardAllocations.isEmpty {
                        if let capacity = localWorkerCapacity, capacity > 0 {
                            let visibleWorkers = min(capacity, 7)
                            ForEach(0..<visibleWorkers, id: \.self) { index in
                                Button {
                                    destination = .identity
                                } label: {
                                    ProtocolCapacityCell(index: index + 1)
                                }
                                .buttonStyle(QuilPressFeedbackButtonStyle())
                            }
                            if capacity > visibleWorkers {
                                ProtocolCapacityOverflowCell(count: capacity - visibleWorkers)
                            }
                        } else {
                            Button {
                                destination = .identity
                            } label: {
                                ProtocolCapacityCell(index: nil)
                            }
                            .buttonStyle(QuilPressFeedbackButtonStyle())
                        }
                    } else {
                        ForEach(monitor.snapshot.shardAllocations) { allocation in
                            Button {
                                destination = .identity
                            } label: {
                                ProtocolAllocationCell(allocation: allocation)
                            }
                            .buttonStyle(QuilPressFeedbackButtonStyle())
                            .accessibilityHint("Opens this allocation in Identity")
                        }
                    }
                }
            }

            if let summary = monitor.snapshot.networkShardSummary {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .foregroundStyle(summary.atRiskShards > 0 ? theme.colors.warning : theme.colors.success)
                    Text("Local shard view")
                        .fontWeight(.semibold)
                    Text("·")
                    Text("\(summary.healthyShards) healthy")
                    Text("·")
                    Text("\(summary.belowTargetShards) below target")
                    Text("·")
                    Text("\(summary.atRiskShards) at risk")
                    Text("·")
                    Text("\(summary.unassignedShards) unassigned")
                    Spacer(minLength: 10)
                    Text(networkTopologyDetail(summary))
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.colors.surface.opacity(0.34))
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(theme.colors.border.opacity(0.42), lineWidth: max(theme.metrics.borderWidth, 0.5))
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: 6) {
                Image(
                    systemName: privacyModeEnabled
                        ? "eye.slash"
                        : monitor.snapshot.shardAllocations.isEmpty
                            ? "hourglass" : "point.3.connected.trianglepath.dotted"
                )
                .foregroundStyle(
                    privacyModeEnabled
                        ? theme.colors.privacy
                        : monitor.snapshot.shardAllocations.isEmpty ? theme.colors.warning : theme.colors.success)
                Text(
                    privacyModeEnabled
                        ? "Sensitive allocation values are hidden; labels and controls remain available."
                        : monitor.snapshot.shardAllocations.isEmpty
                            ? monitor.snapshot.totalAllocations > 0
                                ? "Aggregate registry state is current; detailed local RPC telemetry is temporarily unavailable."
                                : "No shard assignment is present in the local registry yet. Capacity remains visible above."
                            : "Each worker lane and coverage value comes from the managed node's local read-only RPC."
                )
                Spacer(minLength: 10)
                Text("Local node only")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 13)
        .background(theme.colors.canvas.opacity(0.76))
        .overlay(alignment: .bottom) { protocolSectionRule }
    }

    private var localWorkerCapacity: Int? {
        if let workers = monitor.snapshot.localWorkerCount, workers > 0 { return workers }
        if monitor.snapshot.allocatedWorkers > 0 { return monitor.snapshot.allocatedWorkers }
        return nil
    }

    private var localCoverageState: ShardCoverageState? {
        let states = monitor.snapshot.shardAllocations.compactMap(\.coverageState)
        if states.contains(.unassigned) { return .unassigned }
        if states.contains(.atRisk) { return .atRisk }
        if states.contains(.belowTarget) { return .belowTarget }
        if states.contains(.healthy) { return .healthy }
        return nil
    }

    private var localCoverageLabel: String {
        localCoverageState?.label ?? "Checking"
    }

    private var localCoverageTint: Color {
        switch localCoverageState {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk, .unassigned: theme.colors.danger
        case nil: theme.colors.info
        }
    }

    private func networkTopologyDetail(_ summary: NetworkShardSummary) -> String {
        let shardText = "\(summary.totalShards) observed data shards"
        guard let worldState = summary.worldState else { return shardText }
        return "\(shardText) · \(worldState) world"
    }

    private var allocationSummaryDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.46))
            .frame(width: max(theme.metrics.borderWidth, 0.5))
            .padding(.vertical, 10)
    }

    var protocolRewardEvidenceSection: some View {
        HStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(rewardTint.opacity(0.13))
                    Image(systemName: rewardSystemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(rewardTint)
                }
                .frame(width: 39, height: 39)

                VStack(alignment: .leading, spacing: 3) {
                    Text("REWARD EVIDENCE")
                        .protocolSectionLabel(color: theme.colors.secondaryText)
                    Text(rewardStatusTitle)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(rewardTint)
                    Text(rewardEvidenceSummary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.colors.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            protocolEvidenceDivider
            ProtocolEvidenceStat(
                title: "Last credit",
                value: monitor.snapshot.lastRewardCreditFrame.map { "Frame \($0.grouped)" } ?? "None observed",
                detail: monitor.snapshot.lastRewardCreditAt?.formatted(date: .abbreviated, time: .shortened)
                    ?? "Local reward log",
                tint: rewardTint,
                privacyField: nil
            )
            protocolEvidenceDivider
            ProtocolEvidenceStat(
                title: "Eligibility",
                value: monitor.snapshot.activeShards > 0 ? "Active" : "Not active",
                detail: monitor.snapshot.activeShards > 0 ? "Shard work assigned" : "Awaiting active shard work",
                tint: monitor.snapshot.activeShards > 0 ? theme.colors.success : theme.colors.warning,
                privacyField: nil
            )
            protocolEvidenceDivider
            ProtocolEvidenceStat(
                title: "QUIL balance",
                value: monitor.snapshot.quilBalance?.compactDecimal ?? "—",
                detail: balanceDetail,
                tint: theme.colors.wallet,
                privacyField: .quilBalance
            )

            Button {
                destination = .activity
            } label: {
                Label("View activity", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(theme.colors.info)
            .padding(.leading, 18)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.colors.surface.opacity(0.58))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.72), lineWidth: max(theme.metrics.borderWidth, 0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var rewardEvidenceSummary: String {
        if chainProgress.state == .archiveRecovery {
            return "Archive recovery is holding new reward-bearing frames. Keep the node online."
        }
        if monitor.snapshot.lastRewardCreditFrame != nil {
            return "A reward credit was observed in the local node log."
        }
        if monitor.snapshot.activeShards > 0 {
            return "Active allocations establish eligibility; no local credit has been observed yet."
        }
        return "Reward eligibility begins only after an allocation becomes active."
    }

    private var protocolEvidenceDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.54))
            .frame(width: max(theme.metrics.borderWidth, 0.5), height: 52)
            .padding(.horizontal, 14)
    }

    private var protocolSectionRule: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.66))
            .frame(height: max(theme.metrics.borderWidth, 0.5))
            .allowsHitTesting(false)
    }
}

private struct ProtocolEvidenceStat: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .protocolSectionLabel(color: theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 126, alignment: .leading)
    }
}
