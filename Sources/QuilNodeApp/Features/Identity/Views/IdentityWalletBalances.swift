import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct IdentityWalletBalances: View {
    @Environment(\.quilTheme) private var theme
    let snapshot: NodeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wallet balances", systemImage: "wallet.bifold")
                    .font(.headline)
                Spacer()
                Text(snapshot.balanceError == nil ? "Local qclient" : "Incomplete read")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            if let balance = snapshot.walletBalance, !balance.isLegacyFormat {
                row(
                    "Confidential coins", component: balance.confidential,
                    detail: "Reported unspent by your node; not a finalized balance.")
                row(
                    "Unshielded legacy coins", component: balance.legacy,
                    detail: "Separate legacy holdings; already shielded coins are excluded.")
                row(
                    "Claimable prover rewards", component: balance.rewards,
                    detail: "Requires minting before these become coins. No mint is performed here.")
            } else {
                HStack {
                    Text("QUIL balance")
                    Spacer()
                    amount(snapshot.quilBalance)
                }
                Text("A current qclient reports confidential coins, legacy coins, and claimable rewards separately.")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            if let error = snapshot.balanceError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(theme.colors.warning)
            }
            if let date = snapshot.balanceUpdatedAt {
                PrivacyProtectedText(
                    value: "Last wallet observation: \(IdentityFreshnessFormatter.string(from: date))",
                    field: .localTimestamp
                )
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
            }
        }
        .padding(14)
        .controlSurface(tint: theme.colors.wallet)
    }

    private func row(_ title: String, component: QuilBalanceComponent?, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                amount(component?.amount)
            }
            Text(componentDetail(component, fallback: detail))
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private func amount(_ value: String?) -> some View {
        PrivacyProtectedText(
            value: value.map { "\($0.compactDecimal) QUIL" } ?? "Unavailable",
            field: value == nil ? nil : .quilBalance
        )
        .font(.subheadline.monospacedDigit())
        .textSelection(.disabled)
    }

    private func componentDetail(_ component: QuilBalanceComponent?, fallback: String) -> String {
        switch component?.state {
        case .noRoot: "The node reports that no QUIL coin root has been published yet."
        case .notApplicable: "This node has no legacy Ed448 identity."
        case .unavailable: "No verified amount was returned. This does not establish a zero balance."
        case nil: "This component was not returned by the client."
        case .observed: fallback
        }
    }
}
