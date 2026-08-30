import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ProtocolAllocationCell: View {
    @Environment(\.quilTheme) private var theme
    let allocation: ShardAllocation

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
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    PrivacyProtectedPhrase(
                        prefix: titlePrefix,
                        value: titleValue,
                        field: .shardAllocation
                    )
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(theme.colors.primaryText)

                    Spacer(minLength: 4)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("Allocation")
                        PrivacyProtectedText(
                            value: presentation.lifecycleLabel,
                            field: .shardAllocation
                        )
                    }
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(lifecycleTint)
                    .lineLimit(1)
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
            "Allocation is \(presentation.lifecycleLabel.lowercased()). "
                + "Shard coverage is \(presentation.coverageLabel?.lowercased() ?? "unavailable")."
        )
    }
}
