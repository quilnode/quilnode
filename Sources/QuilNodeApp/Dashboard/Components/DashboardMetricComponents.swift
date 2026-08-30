import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct HeroValue: View {
    let title: String
    let value: String
    let privacyField: PrivacyField?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100, alignment: .trailing)
    }
}

struct RewardJourneyPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

struct DashboardSectionHeader: View {
    let title: String
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 4)
    }
}

struct DashboardMetricControl: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        HStack(spacing: 12) {
            DashboardCircleIcon(systemImage: systemImage, tint: tint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.title3.bold().monospacedDigit())
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .controlSurface()
    }
}

struct ActivityControl: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DashboardCircleIcon(systemImage: systemImage, tint: tint, size: 36)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(15)
        .frame(width: 180)
        .frame(minHeight: 116, alignment: .leading)
        .controlSurface()
    }
}

struct LocalSourceBadge: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "lock.shield.fill")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Source: \(title.lowercased())")
    }
}

struct ShardAllocationRow: View {
    @Environment(\.quilTheme) private var theme
    let allocation: ShardAllocation
    let currentFrame: UInt64

    private var tint: Color {
        switch allocation.status.lowercased() {
        case "active": theme.colors.success
        case "joining": theme.colors.warning
        case "paused": theme.colors.warning
        case "leaving", "expiredjoin", "expiredleave", "re-confirm!": theme.colors.danger
        default: .secondary
        }
    }

    private var timingDetail: String {
        if let action = allocation.action { return action }
        if let confirm = allocation.confirmFrame, confirm > currentFrame {
            return "Confirm frame \(confirm.grouped) · \((confirm - currentFrame).grouped) frames away"
        }
        if let join = allocation.joinFrame { return "Joined at frame \(join.grouped)" }
        if let last = allocation.lastActiveFrame { return "Last active at frame \(last.grouped)" }
        return allocation.worker.map { "Worker \($0)" } ?? "Lifecycle reported locally"
    }

    var body: some View {
        HStack(spacing: 12) {
            DashboardCircleIcon(
                systemImage: allocation.status.lowercased() == "active" ? "bolt.fill" : "hourglass",
                tint: tint,
                size: 34
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Allocation \(allocation.index + 1)")
                        .font(.subheadline.weight(.semibold))
                    Text(allocation.status)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tint.opacity(0.10), in: Capsule())
                }
                Text(timingDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(allocation.filter.compactIdentifier)
                    .font(.caption.monospaced())
                Text("shard filter")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
