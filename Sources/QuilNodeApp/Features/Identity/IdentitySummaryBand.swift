import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct IdentitySummaryBand: View {
    @Environment(\.quilTheme) private var theme

    let presentation: IdentityWorkspacePresentation

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            participation
                .frame(maxWidth: .infinity, alignment: .leading)

            summaryDivider
            seniority
                .frame(width: 148, alignment: .leading)

            summaryDivider
            allocation
                .frame(width: 118, alignment: .leading)

            summaryDivider
            balance
                .frame(width: 112, alignment: .leading)

            summaryDivider
            evidence
                .frame(width: 126, alignment: .leading)
        }
        .padding(14)
        .frame(minHeight: 138)
        .controlSurface(tint: participationTint)
    }

    private var participation: some View {
        HStack(alignment: .top, spacing: 12) {
            DashboardCircleIcon(
                systemImage: presentation.participation.symbol,
                tint: participationTint,
                size: 42
            )

            VStack(alignment: .leading, spacing: 5) {
                summaryLabel("Participation")
                Text(presentation.participation.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(presentation.participation.detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    IdentityStatusPill(
                        title: presentation.seniority > 0 ? "Chain value read" : "Chain value pending",
                        systemImage: presentation.seniority > 0 ? "checkmark.shield" : "clock",
                        tint: presentation.seniority > 0 ? theme.colors.success : theme.colors.warning
                    )
                    IdentityStatusPill(
                        title: "Local evidence",
                        systemImage: "lock.shield.fill",
                        tint: theme.colors.info
                    )
                }
            }
        }
        .padding(.trailing, 12)
    }

    private var seniority: some View {
        VStack(alignment: .leading, spacing: 5) {
            summaryLabel("Chain seniority")
            Text("Consensus value")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)

            PrivacyProtectedText(
                value: presentation.seniority > 0
                    ? presentation.seniority.formatted(.number.grouping(.automatic))
                    : "Reading…",
                field: presentation.seniority > 0 ? .seniority : nil
            )
            .font(.system(size: 17, weight: .bold, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            IdentityTrendLabel(trend: presentation.seniorityTrend)
        }
        .padding(.horizontal, 12)
    }

    private var allocation: some View {
        VStack(alignment: .leading, spacing: 5) {
            summaryLabel("Allocation")
            Text("Shard work")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)

            PrivacyProtectedPhrase(
                value: String(presentation.totalAllocations),
                suffix: " total",
                field: .allocationCount
            )
            .font(.callout.weight(.semibold))

            allocationState
                .font(.caption2.weight(.semibold))
                .foregroundStyle(allocationTint)
        }
        .padding(.horizontal, 12)
    }

    private var balance: some View {
        VStack(alignment: .leading, spacing: 5) {
            summaryLabel("QUIL balance")
            Text("Spendable")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)

            PrivacyProtectedText(
                value: presentation.balance.map { "\(IdentityBalanceFormatter.compact($0)) QUIL" }
                    ?? "Unavailable",
                field: presentation.balance == nil ? nil : .quilBalance
            )
            .font(.callout.weight(.semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text("Local QClient")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(.horizontal, 12)
    }

    private var evidence: some View {
        VStack(alignment: .leading, spacing: 5) {
            summaryLabel("Chain evidence")
            Text("Local chain view")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)

            Label(presentation.chainEvidenceSource, systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.success)
                .lineLimit(1)

            PrivacyProtectedText(
                value: presentation.chainEvidenceAt.map(IdentityFreshnessFormatter.string) ?? "Pending",
                field: presentation.chainEvidenceAt == nil ? nil : .localTimestamp,
                mask: .compact
            )
            .font(.caption2.monospacedDigit())
            .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(.leading, 12)
    }

    private var summaryDivider: some View {
        Divider()
            .overlay(theme.colors.border.opacity(0.58))
            .frame(height: 92)
    }

    private func summaryLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.75)
            .foregroundStyle(theme.colors.secondaryText)
    }

    @ViewBuilder
    private var allocationState: some View {
        if presentation.activeShards > 0 {
            PrivacyProtectedPhrase(
                value: String(presentation.activeShards),
                suffix: " active",
                field: .activeShardCount
            )
        } else if presentation.pendingJoins > 0 {
            PrivacyProtectedPhrase(
                value: String(presentation.pendingJoins),
                suffix: " joining",
                field: .allocationCount
            )
        } else {
            Text("None active")
        }
    }

    private var participationTint: Color {
        presentation.participation.state.tint(in: theme)
    }

    private var allocationTint: Color {
        presentation.activeShards > 0 ? theme.colors.success : theme.colors.secondaryText
    }
}

struct IdentityStatusPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.26), lineWidth: 0.6))
            .lineLimit(1)
    }
}

struct IdentityTrendLabel: View {
    @Environment(\.quilTheme) private var theme
    let trend: SeniorityTrend

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
            Text("7-day")
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(
                value: value,
                field: trend.direction == .collecting ? nil : .seniority,
                mask: .compact
            )
        }
        .font(.caption2.weight(.semibold).monospacedDigit())
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Seven day seniority trend, \(value)")
    }

    private var value: String {
        switch trend.direction {
        case .collecting: "Collecting"
        case .increased: "+\(trend.delta.formatted(.number.grouping(.automatic)))"
        case .unchanged: "No change"
        case .decreased: trend.delta.formatted(.number.grouping(.automatic))
        }
    }

    private var symbol: String {
        switch trend.direction {
        case .collecting: "ellipsis"
        case .increased: "arrow.up.right"
        case .unchanged: "minus"
        case .decreased: "arrow.down.right"
        }
    }

    private var tint: Color {
        switch trend.direction {
        case .collecting: theme.colors.secondaryText
        case .increased: theme.colors.success
        case .unchanged: theme.colors.info
        case .decreased: theme.colors.warning
        }
    }
}

enum IdentityFreshnessFormatter {
    static func string(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

extension IdentityParticipationPresentation.State {
    func tint(in theme: QuilTheme) -> Color {
        switch self {
        case .offline: theme.colors.danger
        case .awaitingAllocation, .allocated: theme.colors.warning
        case .joining: theme.colors.info
        case .active: theme.colors.success
        }
    }
}
