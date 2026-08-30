import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var networkSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionHeader(title: "Network & allocations", systemImage: "network")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                DashboardMetricControl(
                    title: "Connected peers",
                    value: "\(monitor.snapshot.peers)",
                    detail: DashboardCopy.Activity.liveMesh,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: theme.colors.info,
                    privacyField: nil
                )
                DashboardMetricControl(
                    title: "Archive access",
                    value: monitor.snapshot.archiveServiceValue,
                    detail: monitor.snapshot.archiveServiceDetail,
                    systemImage: "externaldrive.connected.to.line.below",
                    tint: theme.colors.info,
                    privacyField: nil
                )
                DashboardMetricControl(
                    title: "Prover-state sync",
                    value: monitor.snapshot.archiveProverStateValue,
                    detail: monitor.snapshot.archiveProverStateDetail,
                    systemImage: monitor.snapshot.archiveProverStateValue == "Waiting"
                        ? "clock.badge.exclamationmark" : "checkmark.arrow.trianglehead.counterclockwise",
                    tint: monitor.snapshot.archiveProverStateValue == "Waiting"
                        ? theme.colors.warning : theme.colors.info,
                    privacyField: nil
                )
                DashboardMetricControl(
                    title: "Allocations",
                    value: String(monitor.snapshot.totalAllocations),
                    detail: allocationDetail,
                    systemImage: "square.grid.3x3.fill",
                    tint: monitor.snapshot.pendingJoins > 0 ? theme.colors.warning : theme.colors.success,
                    privacyField: .allocationCount
                )
                DashboardMetricControl(
                    title: "Active shards",
                    value: String(monitor.snapshot.activeShards),
                    detail: monitor.snapshot.activeShards > 0
                        ? DashboardCopy.Activity.servingNow
                        : "Not active",
                    systemImage: "checkmark.seal.fill",
                    tint: monitor.snapshot.activeShards > 0 ? theme.colors.success : .secondary,
                    privacyField: .activeShardCount
                )
            }
        }
    }

    var networkClockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DashboardSectionHeader(title: "Network clock & sync", systemImage: "clock.badge.checkmark")
                Spacer()
                LocalSourceBadge(title: "LOCAL NODE")
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Epoch \(currentEpoch.grouped)")
                                .font(.title3.bold().monospacedDigit())
                            Text(epochProgressLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int((epochProgress * 100).rounded()))%")
                            .font(.headline.bold().monospacedDigit())
                    }
                    ProgressView(value: epochProgress)
                        .tint(theme.colors.frame)
                    HStack {
                        Label(
                            "\(framesUntilEpoch.grouped) frames left",
                            systemImage: "flag.checkered"
                        )
                        Spacer()
                        Text(epochETA)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 126)
                .controlSurface(tint: theme.colors.frame)

                DashboardMetricControl(
                    title: "Frames received",
                    value: monitor.snapshot.framesReceived.grouped,
                    detail: "Since this node start",
                    systemImage: "arrow.down.circle.fill",
                    tint: theme.colors.success,
                    privacyField: nil
                )
                .frame(width: 230)

                DashboardMetricControl(
                    title: "Router drops",
                    value: monitor.snapshot.routerDrops.grouped,
                    detail: monitor.snapshot.routerDrops == 0
                        ? "No dropped messages" : "Filtered invalid or stale traffic",
                    systemImage: "shield.lefthalf.filled",
                    tint: monitor.snapshot.routerDrops == 0 ? theme.colors.success : theme.colors.warning,
                    privacyField: nil
                )
                .frame(width: 210)
            }
        }
    }

    var lifecycleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionHeader(title: "Node controls", systemImage: "power")
            LifecycleControlBar(compact: false)
        }
    }

    var operationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardSectionHeader(title: "Resources & wallet", systemImage: "gauge.with.dots.needle.67percent")

            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 16) {
                    ResourceMeter(
                        title: "Node CPU",
                        value: cpuUsage.valueText,
                        fraction: cpuUsage.fraction,
                        systemImage: "cpu",
                        tint: theme.colors.info,
                        cpuDetail: cpuUsage
                    )
                    ResourceMeter(
                        title: "Memory",
                        value: monitor.snapshot.memoryMB.map { String(format: "%.0f MB", $0) } ?? "—",
                        fraction: memoryFraction,
                        systemImage: "memorychip",
                        tint: theme.colors.accentSecondary
                    )
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 116)
                .controlSurface()

                ActivityControl(
                    title: "QUIL balance",
                    value: monitor.snapshot.quilBalance?.compactDecimal ?? "—",
                    detail: balanceDetail,
                    systemImage: "wallet.bifold.fill",
                    tint: monitor.snapshot.quilBalance == nil ? .secondary : theme.colors.wallet,
                    privacyField: .quilBalance
                )
            }

            DisclosureGroup(isExpanded: $allocationsExpanded) {
                VStack(spacing: 0) {
                    if monitor.snapshot.shardAllocations.isEmpty {
                        HStack(spacing: 12) {
                            DashboardCircleIcon(systemImage: "hourglass", tint: theme.colors.warning, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                PrivacyProtectedPhrase(
                                    value: String(monitor.snapshot.totalAllocations),
                                    suffix: " allocations summarized locally",
                                    field: .allocationCount
                                )
                                .font(.subheadline.weight(.semibold))
                                Text(
                                    "Detailed worker and shard topology is temporarily unavailable. The aggregate registry counts above remain local and nothing is inferred from an explorer."
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    } else {
                        ForEach(Array(monitor.snapshot.shardAllocations.enumerated()), id: \.element.id) {
                            offset, allocation in
                            ShardAllocationRow(allocation: allocation, currentFrame: effectiveFrame)
                            if offset < monitor.snapshot.shardAllocations.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Label("Shard allocations", systemImage: "square.grid.3x3.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    allocationBreakdownView
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .controlSurface()
        }
    }

    var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                DashboardSectionHeader(title: "Local history", systemImage: "chart.xyaxis.line")
                Spacer()
                Picker("History range", selection: $historyRange) {
                    ForEach(HistoryRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }

            let visiblePoints = history.points(since: historyRange.interval)
            Group {
                if visiblePoints.count < 2 {
                    HStack(spacing: 12) {
                        DashboardCircleIcon(systemImage: "waveform.path.ecg", tint: theme.colors.info, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Collecting local history")
                                .font(.subheadline.weight(.semibold))
                            Text(
                                "A private sample is saved every 30 seconds. The first chart appears after two samples."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                } else {
                    if privacyModeEnabled {
                        Label("Allocation history hidden", systemImage: "eye.slash.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.colors.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }
                    Chart(visiblePoints) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Count", point.peers),
                            series: .value("Metric", "Peers")
                        )
                        .foregroundStyle(theme.colors.info)
                        .interpolationMethod(.catmullRom)

                        if !privacyModeEnabled {
                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Count", point.pendingJoins),
                                series: .value("Metric", "Joining")
                            )
                            .foregroundStyle(theme.colors.warning)
                            .interpolationMethod(.stepEnd)

                            LineMark(
                                x: .value("Time", point.timestamp),
                                y: .value("Count", point.activeShards),
                                series: .value("Metric", "Active shards")
                            )
                            .foregroundStyle(theme.colors.success)
                            .interpolationMethod(.stepEnd)
                        }
                    }
                    .chartLegend(position: .top, alignment: .leading)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) {
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 190)
                    .padding(16)
                }
            }
            .controlSurface()

            HStack(spacing: 14) {
                Label("7-day retention", systemImage: "calendar")
                Label("30-second samples", systemImage: "timer")
                Label("Stored only on this Mac", systemImage: "internaldrive")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }

}
