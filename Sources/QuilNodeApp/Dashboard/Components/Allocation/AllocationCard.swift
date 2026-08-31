import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ProtocolAllocationCell: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons
    let allocation: ShardAllocation
    var clock: NodeEpochClock? = nil

    private var presentation: AllocationCellPresentation {
        AllocationCellPresentation(allocation: allocation)
    }

    private var isActive: Bool {
        presentation.lifecycle == .active
    }

    private var titlePrefix: String {
        allocation.worker?.isEmpty == false ? "Worker " : "Allocation "
    }

    private var titleValue: String {
        guard let worker = allocation.worker, !worker.isEmpty else {
            return String(allocation.index + 1)
        }
        let prefix = "worker "
        return worker.lowercased().hasPrefix(prefix)
            ? String(worker.dropFirst(prefix.count))
            : worker
    }

    private var coverageTint: Color {
        switch allocation.coverageState {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk, .unassigned: theme.colors.danger
        case nil: isActive ? theme.colors.info : theme.colors.secondaryText
        }
    }

    private var lifecycleTint: Color {
        switch presentation.lifecycle {
        case .active: theme.colors.success
        case .joining, .leaving: theme.colors.warning
        case .attention: theme.colors.danger
        case .unknown: theme.colors.secondaryText
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(lifecycleTint)
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? lifecycleTint.opacity(0.58) : .clear, radius: 4)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        workerHeading
                        Spacer(minLength: 4)
                        lifecycleHeading
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 4) {
                        workerHeading
                        lifecycleHeading
                    }
                }

                Group {
                    if allocation.filter.isEmpty {
                        Text("Global allocation")
                    } else {
                        PrivacyProtectedPhrase(
                            prefix: "Shard ",
                            value: allocation.filter.compactIdentifier,
                            field: .shardAllocation
                        )
                    }
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                if let ring = allocation.ring,
                    let activeProvers = allocation.activeProvers,
                    let coverageState = allocation.coverageState
                {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("Coverage")
                        PrivacyProtectedText(value: coverageState.label, field: .shardAllocation)
                            .foregroundStyle(coverageTint)
                        Text("·")
                        PrivacyProtectedText(value: String(activeProvers), field: .shardAllocation)
                        Text(activeProvers == 1 ? "prover" : "provers")
                        Text("·")
                        Text("Ring")
                        PrivacyProtectedText(value: String(ring), field: .shardAllocation)
                    }
                    .font(.system(size: 8.7, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }

                if let timing = AllocationEpochPresentation(allocation: allocation, clock: clock) {
                    PrivacyProtectedPhrase(
                        prefix: timing.label + " · ",
                        value: timing.value,
                        field: .shardAllocation
                    )
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(
                        redactionReasons.contains(.privacy)
                            ? "Allocation timing hidden by Privacy Mode" : timing.explanation)
                }
            }
            Spacer(minLength: 0)
        }
        .protocolAllocationCardSurface(
            theme: theme,
            borderColor: lifecycleTint.opacity(0.60),
            emphasized: isActive
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint(
            redactionReasons.contains(.privacy)
                ? "Allocation details hidden by Privacy Mode"
                : "Allocation is \(presentation.lifecycleLabel.lowercased()). "
                    + "Shard coverage is \(presentation.coverageLabel?.lowercased() ?? "unavailable")."
        )
    }

    private var workerHeading: some View {
        PrivacyProtectedPhrase(prefix: titlePrefix, value: titleValue, field: .shardAllocation)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(theme.colors.primaryText)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var lifecycleHeading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("Allocation")
            PrivacyProtectedText(value: presentation.lifecycleLabel, field: .shardAllocation)
        }
        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
        .foregroundStyle(lifecycleTint)
        .fixedSize(horizontal: true, vertical: false)
    }
}
