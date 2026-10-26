import QuilNodeCore
import SwiftUI

/// Wallet components intentionally remain separate: a reward is not a coin,
/// and a failed confidential read must never erase a successful reward read.
struct IdentityWalletBalances: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var layout
    let snapshot: NodeSnapshot
    @State private var showExactAmounts = false
    @State private var copiedTitle: String?

    private var freshness: ObservationFreshness {
        ObservationFreshness(observedAt: snapshot.balanceUpdatedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Label("Balances", systemImage: "wallet.bifold")
                    .font(.headline)
                Spacer()
                PrivacyProtectedText(value: "Local qclient · \(freshness.label)", field: .localTimestamp)
                    .font(.caption)
                    .foregroundStyle(freshness.isCurrent ? theme.colors.secondaryText : theme.colors.warning)
            }
            if let balance = snapshot.walletBalance, !balance.isLegacyFormat {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: layout.isCompact ? 1 : 3),
                    spacing: 12
                ) {
                    componentCard(
                        "Claimable rewards", component: balance.rewards,
                        detail: "Requires minting before it becomes coins.", symbol: "sparkles")
                    componentCard(
                        "Confidential coins", component: balance.confidential,
                        detail: "Reported unspent locally; finality is not established by this read.",
                        symbol: "lock.shield")
                    componentCard(
                        "Legacy coins", component: balance.legacy,
                        detail: "Unshielded holdings. Already shielded coins are excluded.",
                        symbol: "clock.arrow.circlepath")
                }
            } else {
                componentCard(
                    "QUIL balance", component: snapshot.quilBalance.map { .init(state: .observed, amount: $0) },
                    detail: "Legacy client observation. A current client reports separate balance components.",
                    symbol: "wallet.bifold")
            }
            if snapshot.balanceError != nil || !freshness.isCurrent {
                Label(
                    snapshot.balanceError != nil
                        ? "Some wallet data is unavailable. Known amounts are retained with their observation time."
                        : "Waiting for a current wallet read. These are the last observed amounts.",
                    systemImage: "info.circle"
                )
                .font(.callout)
                .foregroundStyle(theme.colors.warning)
                .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Exact amounts & read details", isExpanded: $showExactAmounts) {
                VStack(alignment: .leading, spacing: 12) {
                    if let balance = snapshot.walletBalance, !balance.isLegacyFormat {
                        exactRow("Claimable rewards", component: balance.rewards)
                        exactRow("Confidential coins", component: balance.confidential)
                        exactRow("Legacy coins", component: balance.legacy)
                    } else {
                        exactRow(
                            "QUIL balance", component: snapshot.quilBalance.map { .init(state: .observed, amount: $0) })
                    }
                    if let date = snapshot.balanceUpdatedAt {
                        PrivacyProtectedText(
                            value: "Observed \(date.formatted(date: .abbreviated, time: .standard))",
                            field: .localTimestamp
                        )
                        .font(.caption)
                    }
                    if let error = snapshot.balanceError {
                        PrivacyProtectedText(value: error, field: .quilBalance)
                            .font(.caption).foregroundStyle(theme.colors.warning)
                    }
                    Text(
                        "≈ marks a shortened amount; < marks a nonzero amount below display precision. Copy always uses the exact decimal value. No transaction is performed on this screen."
                    )
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                }
                .padding(.top, 12)
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(18)
        .controlSurface(tint: theme.colors.wallet.opacity(0.5))
    }

    private func amount(_ component: QuilBalanceComponent?) -> TokenAmountPresentation {
        guard component?.state == .observed || component?.state == .noRoot else { return .init(nil) }
        return .init(component?.amount)
    }

    private func componentCard(_ title: String, component: QuilBalanceComponent?, detail: String, symbol: String)
        -> some View
    {
        let value = amount(component)
        return VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.medium))
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value.exact == nil ? "Unavailable" : value.compact, field: .quilBalance)
                .font(
                    .system(size: 28 * theme.typography.scale, weight: .semibold, design: theme.typography.dataDesign)
                        .monospacedDigit()
                )
                .foregroundStyle(value.exact == nil ? theme.colors.secondaryText : theme.colors.wallet)
                .lineLimit(2).minimumScaleFactor(0.75)
            Text(component?.state == .notApplicable ? "Not applicable" : "QUIL")
                .font(.caption.weight(.medium)).foregroundStyle(theme.colors.secondaryText)
            Text(componentDetail(component, fallback: detail))
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
        .padding(14)
        .background(theme.colors.canvas.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func exactRow(_ title: String, component: QuilBalanceComponent?) -> some View {
        let value = amount(component)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline)
                Spacer()
                Button {
                    IdentityActions.copy(value.exact)
                    copiedTitle = title
                } label: {
                    Label(
                        copiedTitle == title ? "Copied" : "Copy exact amount",
                        systemImage: copiedTitle == title ? "checkmark" : "doc.on.doc")
                }
                .disabled(value.exact == nil)
                .accessibilityLabel("Copy exact \(title.lowercased()) amount")
            }
            PrivacyProtectedText(value: value.exact.map { "\($0) QUIL" } ?? "Unavailable", field: .quilBalance)
                .font(.callout.monospacedDigit()).fixedSize(horizontal: false, vertical: true)
            if let frame = component?.frame {
                PrivacyProtectedText(value: "Reported at frame \(frame.grouped)", field: .rewardActivity)
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
        }
    }

    private func componentDetail(_ component: QuilBalanceComponent?, fallback: String) -> String {
        switch component?.state {
        case .noRoot: "The node reports no published QUIL coin root yet."
        case .notApplicable: "This node has no legacy Ed448 identity."
        case .unavailable: "No amount returned. Unavailable does not mean zero."
        case nil: "This component was not returned by the client."
        case .observed: fallback
        }
    }
}
