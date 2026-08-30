import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var overviewAllocationPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                HStack(spacing: 6) {
                    Label("Participation & rewards", systemImage: "seal.fill")
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(rewardStatusDetail)
                        .accessibilityLabel("Reward status information")
                        .accessibilityHint(rewardStatusDetail)
                }
                .font(.subheadline.weight(.semibold))
                Spacer()
                Text("LOCAL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    PrivacyProtectedText(
                        value: String(monitor.snapshot.activeShards),
                        field: .activeShardCount
                    )
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    Text("active shards")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("REWARDS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(rewardStatusTitle)
                        .font(.headline.bold())
                        .foregroundStyle(rewardTint)
                        .help(rewardStatusDetail)
                }
            }
            HStack(spacing: 8) {
                RewardJourneyPill(
                    title: monitor.snapshot.seniority > 0 ? "Enrolled" : "Reading enrollment",
                    systemImage: monitor.snapshot.seniority > 0 ? "checkmark" : "ellipsis",
                    tint: monitor.snapshot.seniority > 0 ? theme.colors.success : .secondary
                )
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                RewardJourneyPill(
                    title: monitor.snapshot.activeShards > 0 ? "Shards active" : "Awaiting shards",
                    systemImage: monitor.snapshot.activeShards > 0 ? "checkmark" : "clock",
                    tint: monitor.snapshot.activeShards > 0 ? theme.colors.success : .secondary
                )
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
                RewardJourneyPill(
                    title: monitor.snapshot.lastRewardCreditFrame == nil ? "No credit observed" : "Credit observed",
                    systemImage: monitor.snapshot.lastRewardCreditFrame == nil ? "clock" : "checkmark",
                    tint: rewardTint
                )
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .controlSurface(tint: monitor.snapshot.activeShards > 0 ? theme.colors.success : theme.colors.warning)
        .accessibilityHint(rewardStatusDetail)
    }

    var overviewRuntimePanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label("Local runtime", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("NO CLOUD")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
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
            HStack {
                Label(
                    "\(monitor.snapshot.framesReceived.grouped) frames received",
                    systemImage: "arrow.down.circle.fill"
                )
                Spacer()
                Label(
                    "\(monitor.snapshot.routerDrops.grouped) dropped",
                    systemImage: "shield.lefthalf.filled"
                )
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .controlSurface()
    }

    var statusHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(healthTint)
                Image(systemName: monitor.snapshot.health.systemImage)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .shadow(color: healthTint.opacity(0.30), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(monitor.snapshot.health.label)
                    .font(.title3.bold())
                Text(statusDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HeroValue(title: "Frame", value: monitor.snapshot.frame.grouped, privacyField: nil)
            Divider()
                .frame(height: 38)
            HeroValue(title: "Pace", value: framePace, privacyField: nil)
            Divider()
                .frame(height: 38)
            HeroValue(title: "Uptime", value: monitor.snapshot.processUptime ?? "—", privacyField: .nodeUptime)
        }
        .padding(18)
        .controlSurface(tint: healthTint)
    }
}
