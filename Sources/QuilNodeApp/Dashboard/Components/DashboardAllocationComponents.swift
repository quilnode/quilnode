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

struct ProtocolPrivateAllocationCell: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "eye.slash")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.colors.privacy)
            VStack(alignment: .leading, spacing: 2) {
                Text("Allocation details hidden")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.colors.primaryText)
                Text("Privacy Mode conceals lane and capacity shape")
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .allocationCellSurface(theme: theme, borderColor: theme.colors.privacy.opacity(0.38))
    }
}

struct ProtocolAllocationCell: View {
    @Environment(\.quilTheme) private var theme
    let allocation: ShardAllocation

    private var isActive: Bool {
        allocation.lastActiveFrame != nil
            || allocation.status.localizedCaseInsensitiveContains("active")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(isActive ? theme.colors.info : theme.colors.secondaryText.opacity(0.46))
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? theme.colors.info.opacity(0.62) : .clear, radius: 4)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                PrivacyProtectedText(
                    value: "Shard \(allocation.index)",
                    field: .shardAllocation
                )
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(isActive ? theme.colors.primaryText : theme.colors.secondaryText)

                PrivacyProtectedText(
                    value: allocation.filter.isEmpty ? allocation.status : allocation.filter,
                    field: .shardAllocation
                )
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(theme.colors.surface.opacity(isActive ? 0.78 : 0.48))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(
                    (isActive ? theme.colors.info : theme.colors.border).opacity(0.60),
                    lineWidth: max(theme.metrics.borderWidth, 0.5)
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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
}
