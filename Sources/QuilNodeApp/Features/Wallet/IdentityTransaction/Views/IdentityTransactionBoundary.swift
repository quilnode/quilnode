import SwiftUI

struct IdentityTransactionBoundary: View {
    @Environment(\.quilTheme) private var theme

    let changes: [IdentityTransactionContractItem]
    let untouched: [IdentityTransactionContractItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Transaction boundary").font(.headline)
                Text("Exactly what may change after confirmation.")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(12)

            Divider().overlay(theme.colors.border.opacity(0.54))
            contractSection("Changes", items: changes, tint: theme.colors.accent)
            Divider().overlay(theme.colors.border.opacity(0.54))
            contractSection("Stays untouched", items: untouched, tint: theme.colors.success)
            Spacer(minLength: 4)
            Label("Private key bytes never enter this interface", systemImage: "lock.shield.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colors.success)
                .padding(12)
        }
        .controlSurface(tint: theme.colors.info)
    }

    private func contractSection(
        _ title: String,
        items: [IdentityTransactionContractItem],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(tint)
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.caption.weight(.semibold))
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
    }
}
