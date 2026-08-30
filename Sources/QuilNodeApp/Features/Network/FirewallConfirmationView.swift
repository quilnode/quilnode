import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct FirewallPromise: View {
    @Environment(\.quilTheme) private var theme
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
    }
}

struct FirewallConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    let confirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                DashboardCircleIcon(
                    systemImage: "checkmark.shield.fill",
                    tint: theme.colors.accent,
                    size: 48
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secure inbound access").font(.title2.bold())
                    Text("One local, verified firewall transaction")
                        .font(.subheadline)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                FirewallChangeRow(
                    symbol: "firewall.fill",
                    title: "Turn on macOS Application Firewall",
                    detail: "Only if it is currently off."
                )
                FirewallChangeRow(
                    symbol: "app.badge.checkmark",
                    title: "Allow the installed node binary",
                    detail:
                        "The trusted helper resolves the fixed node link itself; the app cannot supply another path."
                )
                FirewallChangeRow(
                    symbol: "arrow.triangle.2.circlepath",
                    title: "Keep the rule current after updates",
                    detail: "QuilNode replaces only the prior rule that it recorded and managed."
                )
                FirewallChangeRow(
                    symbol: "hand.raised.fill",
                    title: "Preserve everything else",
                    detail: "Existing app rules, Block All, Stealth Mode, and router settings are not changed."
                )
            }
            .padding(16)
            .background(
                theme.colors.surfaceElevated.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            Text(
                "Your existing passwordless QuilNode service performs this fixed operation. No router password or private key is read, stored, or transmitted."
            )
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Enable & allow node", systemImage: "checkmark.shield") { confirm() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .accessibilityElement(children: .contain)
    }
}

struct FirewallChangeRow: View {
    @Environment(\.quilTheme) private var theme
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.colors.accent)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
