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
                    Text("Network shard coverage").fontWeight(.semibold)
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
                Text(allocationEvidenceNote)
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
        if monitor.snapshot.shardAllocations.isEmpty, monitor.snapshot.totalAllocations > 0 {
            return .aggregate
        }
        return monitor.snapshot.shardAllocations.isEmpty ? .capacity : .allocations
    }

    private var allocationEvidenceNote: String {
        if !nodeObservation.hasLiveTelemetry {
            return "Loading worker capacity, shard assignments and coverage from the local node."
        }
        if privacyModeEnabled {
            return
                "Allocation layout is hidden behind a fixed placeholder that does not reveal worker or allocation count."
        }
        if monitor.snapshot.shardAllocations.isEmpty {
            return monitor.snapshot.totalAllocations > 0
                ? "Aggregate registry state is current; detailed local RPC telemetry is temporarily unavailable."
                : "No shard assignment is present in the local registry yet. Capacity remains visible above."
        }
        return "Each card separates the allocation lifecycle from the assigned shard's network coverage."
    }

    private var localCoverageState: ShardCoverageState? { allocationLattice.coverageState }
    private var localCoverageLabel: String { localCoverageState?.label ?? "Checking" }

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

    private var protocolSectionRule: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.66))
            .frame(height: max(theme.metrics.borderWidth, 0.5))
            .allowsHitTesting(false)
    }
}
