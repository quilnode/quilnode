import SwiftUI

struct ProtocolAllocationSummaryStat: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .protocolSectionLabel(color: theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 15, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct ProtocolAllocationRelationshipSummary: View {
    @Environment(\.quilTheme) private var theme

    let presentation: AllocationLatticePresentation
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if isLoading {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(theme.colors.info)
                    Text("Loading worker runtime, allocation state and shard coverage…")
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        runningWorkersValue
                        Text("·")
                        activeAllocationsValue
                        Text("·")
                        joiningAllocationsValue
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        runningWorkersValue
                        activeAllocationsValue
                        joiningAllocationsValue
                    }
                }
            }

            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.colors.info)
                Text("A running worker can still have a joining allocation.")
                Text("“Healthy” describes shard coverage, not worker status.")
                    .fontWeight(.semibold)
            }
        }
        .font(.system(size: 9.5, design: .monospaced))
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surface.opacity(0.32))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.42), lineWidth: max(theme.metrics.borderWidth, 0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var runningWorkersValue: some View {
        PrivacyProtectedPhrase(
            value: presentation.runningWorkers.map(String.init) ?? "—",
            suffix: " workers running",
            field: .hardwareProfile
        )
        .foregroundStyle(theme.colors.info)
    }

    private var activeAllocationsValue: some View {
        PrivacyProtectedPhrase(
            value: String(presentation.activeAllocations),
            suffix: " allocations active",
            field: .activeShardCount
        )
        .foregroundStyle(theme.colors.success)
    }

    private var joiningAllocationsValue: some View {
        PrivacyProtectedPhrase(
            value: String(presentation.joiningAllocations),
            suffix: " allocations joining",
            field: .allocationCount
        )
        .foregroundStyle(
            presentation.joiningAllocations > 0
                ? theme.colors.warning : theme.colors.secondaryText
        )
    }
}

struct ProtocolCapacityCell: View {
    @Environment(\.quilTheme) private var theme
    let index: Int?

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .strokeBorder(
                    theme.colors.info.opacity(index == nil ? 0.32 : 0.58),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                if let index {
                    PrivacyProtectedPhrase(
                        prefix: "Worker ",
                        value: String(index),
                        field: .hardwareProfile
                    )
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.primaryText)
                } else {
                    Text("Capacity unavailable")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.colors.primaryText)
                }
                Text(index == nil ? "Waiting for local telemetry" : "Awaiting shard assignment")
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .allocationCellSurface(theme: theme)
    }
}

struct ProtocolCapacityOverflowCell: View {
    @Environment(\.quilTheme) private var theme
    let count: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(theme.colors.info)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                PrivacyProtectedPhrase(
                    prefix: "+",
                    value: String(count),
                    suffix: count == 1 ? " worker" : " workers",
                    field: .hardwareProfile
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                Text("Awaiting assignment")
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .allocationCellSurface(theme: theme)
    }
}

struct ProtocolAggregateAllocationCell: View {
    @Environment(\.quilTheme) private var theme
    let active: Int
    let joining: Int
    let total: Int

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "rectangle.stack.badge.person.crop")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.info)
            VStack(alignment: .leading, spacing: 4) {
                Text("Registry allocation summary")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.primaryText)
                HStack(spacing: 5) {
                    PrivacyProtectedPhrase(
                        value: String(active),
                        suffix: " active",
                        field: .activeShardCount
                    )
                    Text("·")
                    PrivacyProtectedPhrase(
                        value: String(joining),
                        suffix: " joining",
                        field: .allocationCount
                    )
                    Text("·")
                    PrivacyProtectedPhrase(
                        value: String(total),
                        suffix: " total",
                        field: .allocationCount
                    )
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(theme.colors.surface.opacity(0.52))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(
                    theme.colors.info.opacity(0.38),
                    lineWidth: max(theme.metrics.borderWidth, 0.5)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
