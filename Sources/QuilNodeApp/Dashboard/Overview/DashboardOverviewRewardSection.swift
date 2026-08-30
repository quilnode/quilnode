import SwiftUI

extension DashboardView {
    var protocolRewardEvidenceSection: some View {
        HStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(rewardTint.opacity(0.13))
                    Image(systemName: rewardSystemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(rewardTint)
                }
                .frame(width: 39, height: 39)

                VStack(alignment: .leading, spacing: 3) {
                    Text("REWARD EVIDENCE")
                        .protocolSectionLabel(color: theme.colors.secondaryText)
                    Text(rewardStatusTitle)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(rewardTint)
                    Text(rewardEvidenceSummary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.colors.secondaryText)
                        .lineLimit(2)
                }
            }
            .padding(.trailing, 20)
            .frame(maxWidth: .infinity, alignment: .leading)

            protocolEvidenceDivider
            ProtocolEvidenceStat(
                title: "Last credit",
                value: monitor.snapshot.lastRewardCreditFrame.map { "Frame \($0.grouped)" } ?? "None observed",
                detail: monitor.snapshot.lastRewardCreditAt?.formatted(date: .abbreviated, time: .shortened)
                    ?? "Local reward log",
                tint: rewardTint,
                privacyField: nil
            )
            protocolEvidenceDivider
            ProtocolEvidenceStat(
                title: "Eligibility",
                value: monitor.snapshot.activeAllocations > 0 ? "Active" : "Not active",
                detail: monitor.snapshot.activeAllocations > 0
                    ? "Active allocations assigned" : "Awaiting active allocations",
                tint: monitor.snapshot.activeAllocations > 0 ? theme.colors.success : theme.colors.warning,
                privacyField: nil
            )
            protocolEvidenceDivider
            ProtocolEvidenceStat(
                title: "QUIL balance",
                value: monitor.snapshot.quilBalance?.compactDecimal ?? "—",
                detail: balanceDetail,
                tint: theme.colors.wallet,
                privacyField: .quilBalance
            )

            Button {
                destination = .activity
            } label: {
                Label("View activity", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(theme.colors.info)
            .padding(.leading, 18)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.colors.surface.opacity(0.58))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.72), lineWidth: max(theme.metrics.borderWidth, 0.5))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var rewardEvidenceSummary: String {
        if chainProgress.state == .archiveRecovery {
            return "Archive recovery is holding new reward-bearing frames. Keep the node online."
        }
        if monitor.snapshot.lastRewardCreditFrame != nil {
            return "A reward credit was observed in the local node log."
        }
        if monitor.snapshot.activeShards > 0 {
            return "Active allocations establish eligibility; no local credit has been observed yet."
        }
        return "Reward eligibility begins only after an allocation becomes active."
    }

    private var protocolEvidenceDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.54))
            .frame(width: max(theme.metrics.borderWidth, 0.5), height: 52)
            .padding(.horizontal, 14)
    }
}

private struct ProtocolEvidenceStat: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .protocolSectionLabel(color: theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 12.5, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 126, alignment: .leading)
    }
}
