import SwiftUI

extension DashboardView {
    var overviewMetricStrip: some View {
        Group {
            if dashboardLayoutClass.isCompact {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3),
                    spacing: 0
                ) {
                    ForEach(overviewMetricDescriptors) { descriptor in
                        ProtocolMetricCell(descriptor: descriptor)
                            .frame(minHeight: 92)
                            .overlay(alignment: .trailing) { protocolMetricDivider }
                            .overlay(alignment: .bottom) { protocolRule(opacity: 0.36) }
                    }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(overviewMetricDescriptors.enumerated()), id: \.element.id) { index, descriptor in
                        if index > 0 { protocolMetricDivider }
                        ProtocolMetricCell(descriptor: descriptor)
                    }
                }
            }
        }
        .frame(minHeight: 112)
        .background(theme.colors.canvas.opacity(0.68))
        .overlay(alignment: .bottom) { protocolRule(opacity: 0.72) }
    }

    private var overviewMetricDescriptors: [ProtocolMetricDescriptor] {
        [
            ProtocolMetricDescriptor(
                id: "allocations",
                title: "Allocations active",
                value: nodeObservation.value(String(monitor.snapshot.activeAllocations)),
                detail: nodeObservation.detail("Local registry"),
                tint: monitor.snapshot.activeAllocations > 0 ? theme.colors.success : protocolSignal,
                privacyField: .activeShardCount
            ),
            ProtocolMetricDescriptor(
                id: "archives",
                title: "Archive sources",
                value: nodeObservation.value(monitor.snapshot.archiveSourceValue),
                detail: nodeObservation.detail(monitor.snapshot.archiveSourceDetail),
                tint: theme.colors.info,
                privacyField: nil
            ),
            ProtocolMetricDescriptor(
                id: "peers",
                title: "Network peers",
                value: nodeObservation.value(String(monitor.snapshot.peers)),
                detail: nodeObservation.detail(DashboardCopy.Activity.liveMesh),
                tint: theme.colors.info,
                privacyField: nil
            ),
            ProtocolMetricDescriptor(
                id: "seniority",
                title: DashboardCopy.Overview.seniority,
                value: nodeObservation.value(
                    monitor.snapshot.seniority > 0 ? monitor.snapshot.seniority.grouped : "—"
                ),
                detail: nodeObservation.detail(DashboardCopy.Overview.chainRegistry),
                tint: theme.colors.accentSecondary,
                privacyField: .seniority
            ),
            ProtocolMetricDescriptor(
                id: "uptime",
                title: DashboardCopy.Overview.uptime,
                value: nodeObservation.value(monitor.snapshot.processUptime ?? "—"),
                detail: nodeObservation.detail(DashboardCopy.Overview.nodeProcess),
                tint: theme.colors.success,
                privacyField: .nodeUptime
            ),
            ProtocolMetricDescriptor(
                id: "balance",
                title: "QUIL balance",
                value: nodeObservation.value(monitor.snapshot.quilBalance?.compactDecimal ?? "—"),
                detail: nodeObservation.detail(balanceDetail),
                tint: theme.colors.wallet,
                privacyField: .quilBalance
            ),
        ]
    }

    private var protocolMetricDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.56))
            .frame(width: max(theme.metrics.borderWidth, 0.5))
            .padding(.vertical, 18)
    }
}
