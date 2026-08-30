import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

private enum ProtocolAllocationLayoutPhase: Hashable {
    case loading
    case privacy
    case aggregate
    case capacity
    case allocations
}

extension DashboardView {
    var protocolAllocationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Allocation lattice")
                    .font(.system(size: 13, weight: .semibold))
                Text("Worker runtime, allocation state and shard coverage")
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
                    title: "Allocations active",
                    value: nodeObservation.value(String(allocationLattice.activeAllocations)),
                    detail: "ready for work",
                    tint: allocationLattice.activeAllocations > 0
                        ? theme.colors.success : theme.colors.secondaryText,
                    privacyField: .activeShardCount
                )
                allocationSummaryDivider
                ProtocolAllocationSummaryStat(
                    title: "Allocations joining",
                    value: nodeObservation.value(String(allocationLattice.joiningAllocations)),
                    detail: "not active yet",
                    tint: allocationLattice.joiningAllocations > 0
                        ? theme.colors.warning : theme.colors.secondaryText,
                    privacyField: .allocationCount
                )
                allocationSummaryDivider
                ProtocolAllocationSummaryStat(
                    title: "Workers running",
                    value: nodeObservation.value(allocationLattice.runningWorkers.map(String.init) ?? "—"),
                    detail: "local runtime",
                    tint: theme.colors.info,
                    privacyField: .hardwareProfile
                )
                allocationSummaryDivider
                ProtocolAllocationSummaryStat(
                    title: "Shard coverage",
                    value: nodeObservation.value(localCoverageLabel),
                    detail: "network resilience",
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

            ProtocolAllocationRelationshipSummary(
                presentation: allocationLattice,
                isLoading: !nodeObservation.hasLiveTelemetry
            )

            ZStack(alignment: .topLeading) {
                protocolAllocationLayout
                    .id(protocolAllocationLayoutPhase)
                    .transition(motion.revealTransition)
            }
            .animation(motion.contentReplacement, value: protocolAllocationLayoutPhase)

            if let summary = monitor.snapshot.networkShardSummary {
                HStack(spacing: 6) {
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .foregroundStyle(summary.atRiskShards > 0 ? theme.colors.warning : theme.colors.success)
                    Text("Network shard coverage")
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
                    !nodeObservation.hasLiveTelemetry
                        ? "Loading worker capacity, shard assignments and coverage from the local node."
                        : privacyModeEnabled
                            ? "Allocation layout is hidden behind a fixed placeholder that does not reveal worker or allocation count."
                            : monitor.snapshot.shardAllocations.isEmpty
                                ? monitor.snapshot.totalAllocations > 0
                                    ? "Aggregate registry state is current; detailed local RPC telemetry is temporarily unavailable."
                                    : "No shard assignment is present in the local registry yet. Capacity remains visible above."
                                : "Each card separates the allocation lifecycle from the assigned shard's network coverage."
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

    @ViewBuilder
    private var protocolAllocationLayout: some View {
        switch protocolAllocationLayoutPhase {
        case .loading:
            ProtocolAllocationPlaceholderLayout(mode: .loading)
        case .privacy:
            ProtocolAllocationPlaceholderLayout(mode: .privacy)
        case .aggregate:
            ProtocolAggregateAllocationCell(
                active: monitor.snapshot.activeShards,
                joining: monitor.snapshot.pendingJoins,
                total: monitor.snapshot.totalAllocations
            )
        case .capacity:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                if let capacity = allocationLattice.runningWorkers, capacity > 0 {
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
            }
        case .allocations:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
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

    private var protocolAllocationLayoutPhase: ProtocolAllocationLayoutPhase {
        if !nodeObservation.hasLiveTelemetry { return .loading }
        if privacyModeEnabled { return .privacy }
        if monitor.snapshot.shardAllocations.isEmpty,
            monitor.snapshot.totalAllocations > 0
        {
            return .aggregate
        }
        return monitor.snapshot.shardAllocations.isEmpty ? .capacity : .allocations
    }

    private var localCoverageState: ShardCoverageState? {
        allocationLattice.coverageState
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
                value: monitor.snapshot.activeAllocations > 0 ? "Active" : "Not active",
                detail: monitor.snapshot.activeAllocations > 0
                    ? "Active allocations assigned" : "Awaiting active allocations",
                tint: monitor.snapshot.activeAllocations > 0 ? theme.colors.success : theme.colors.warning,
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
