import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

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
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 15, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                PrivacyProtectedText(
                    value: index.map { "Worker \($0)" } ?? "Capacity unavailable",
                    field: index == nil ? nil : .hardwareProfile
                )
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.colors.primaryText)
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

enum ProtocolAllocationPlaceholderMode: Hashable {
    case loading
    case privacy
}

/// A fixed-density replacement for worker and allocation cards before live
/// telemetry arrives and while Privacy Mode is active. It deliberately reuses
/// the live card geometry without using any real record count or state.
struct ProtocolAllocationPlaceholderLayout: View {
    @Environment(\.quilTheme) private var theme

    let mode: ProtocolAllocationPlaceholderMode

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: PrivacyLayoutPolicy.collectionPlaceholderCount
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<PrivacyLayoutPolicy.collectionPlaceholderCount, id: \.self) { _ in
                HStack(alignment: .top, spacing: 9) {
                    leadingIndicator
                    VStack(alignment: .leading, spacing: 2) {
                        placeholderTitle
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.colors.primaryText)
                        placeholderDetail
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(theme.colors.secondaryText)
                            .lineLimit(1)
                        placeholderMetadata
                            .font(.system(size: 8.7, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.colors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                }
                .protocolAllocationCardSurface(
                    theme: theme,
                    borderColor: tint.opacity(0.60),
                    emphasized: mode == .privacy
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .help(helpText)
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if mode == .loading {
            ProgressView()
                .controlSize(.small)
                .tint(theme.colors.info)
                .frame(width: 8, height: 8)
                .padding(.top, 2)
        } else {
            Circle()
                .fill(theme.colors.privacy)
                .frame(width: 8, height: 8)
                .padding(.top, 3)
        }
    }

    @ViewBuilder
    private var placeholderTitle: some View {
        if mode == .loading {
            Text("Worker —")
        } else {
            maskedPhrase(label: "Worker", mask: .compact)
        }
    }

    @ViewBuilder
    private var placeholderDetail: some View {
        if mode == .loading {
            Text("Shard —")
        } else {
            maskedPhrase(label: "Shard", mask: .identifier)
        }
    }

    @ViewBuilder
    private var placeholderMetadata: some View {
        if mode == .loading {
            Text("Ring — · — provers · Coverage —")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Ring ")
                Text(PrivacyMaskStyle.compact.text)
                Text(" · ")
                Text(PrivacyMaskStyle.compact.text)
                Text(" provers · Coverage ")
                Text(PrivacyMaskStyle.identifier.text)
            }
        }
    }

    private func maskedPhrase(label: String, mask: PrivacyMaskStyle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(label) ")
            Text(mask.text)
                .tracking(1)
        }
    }

    private var tint: Color {
        mode == .loading ? theme.colors.info : theme.colors.privacy
    }

    private var accessibilityLabel: String {
        switch mode {
        case .loading:
            "Loading worker, shard assignment, and coverage telemetry."
        case .privacy:
            "Worker and allocation layout hidden by Privacy Mode. The three placeholders are decorative and do not reveal a count."
        }
    }

    private var helpText: String {
        mode == .loading
            ? "Loading local allocation telemetry"
            : "Fixed privacy placeholder — does not represent the worker or allocation count"
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

struct ProtocolAllocationCell: View {
    @Environment(\.quilTheme) private var theme
    let allocation: ShardAllocation

    private var isActive: Bool {
        allocation.lastActiveFrame != nil
            || allocation.status.localizedCaseInsensitiveContains("active")
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

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(coverageTint)
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? coverageTint.opacity(0.58) : .clear, radius: 4)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                PrivacyProtectedPhrase(
                    prefix: titlePrefix,
                    value: titleValue,
                    field: .shardAllocation
                )
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isActive ? theme.colors.primaryText : theme.colors.secondaryText)

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
                        Text("Ring")
                        PrivacyProtectedText(value: String(ring), field: .shardAllocation)
                        Text("·")
                        PrivacyProtectedText(value: String(activeProvers), field: .shardAllocation)
                        Text(activeProvers == 1 ? "prover" : "provers")
                        Text("·")
                        PrivacyProtectedText(value: coverageState.label, field: .shardAllocation)
                            .foregroundStyle(coverageTint)
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
            borderColor: allocation.coverageState == nil
                ? (isActive ? theme.colors.info : theme.colors.border).opacity(0.60)
                : coverageTint.opacity(0.60),
            emphasized: isActive
        )
    }
}

extension View {
    func protocolSectionLabel(color: Color) -> some View {
        font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(color)
    }

    fileprivate func allocationCellSurface(theme: QuilTheme, borderColor: Color? = nil) -> some View {
        padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(theme.colors.surface.opacity(0.46))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        borderColor ?? theme.colors.border.opacity(0.48),
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    fileprivate func protocolAllocationCardSurface(
        theme: QuilTheme,
        borderColor: Color,
        emphasized: Bool
    ) -> some View {
        padding(.horizontal, 11)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(theme.colors.surface.opacity(emphasized ? 0.78 : 0.48))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        lineWidth: max(theme.metrics.borderWidth, 0.5)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
