import SwiftUI

struct IdentityTransactionDossier: View {
    @Environment(\.quilTheme) private var theme

    let presentation: IdentityTransactionPresentation
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                DashboardCircleIcon(systemImage: dossierSymbol, tint: theme.colors.success, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title).font(.headline)
                    Text(presentation.detail)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if presentation.warningCount > 0 {
                    Label(
                        "\(presentation.warningCount) warning\(presentation.warningCount == 1 ? "" : "s")",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.colors.warning)
                } else {
                    Label(evidenceBadgeTitle, systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.colors.success)
                }
            }
            .padding(13)

            Divider().overlay(theme.colors.border.opacity(0.54))
            VStack(spacing: 0) {
                ForEach(presentation.facts) { fact in
                    factRow(fact)
                    if fact.id != presentation.facts.last?.id {
                        Divider().overlay(theme.colors.border.opacity(0.36))
                    }
                }
            }

            if presentation.requiresEditableName {
                Divider().overlay(theme.colors.border.opacity(0.54))
                VStack(alignment: .leading, spacing: 5) {
                    OnboardingSectionLabel(text: "Local identity label")
                    TextField("Identity name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Local identity label")
                    Text("Stored locally for your organization; never published to the network.")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                .padding(12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .controlSurface(tint: theme.colors.success)
    }

    private func factRow(_ fact: IdentityTransactionFact) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol(for: fact))
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint(for: fact))
                .frame(width: 24, height: 24)
                .background(tint(for: fact).opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
            Text(fact.title)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 116, alignment: .leading)
            PrivacyProtectedText(value: fact.value, field: fact.privacyField, mask: fact.mask)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(stateLabel(for: fact.state))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.45)
                .foregroundStyle(tint(for: fact))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
    }

    private var dossierSymbol: String {
        switch presentation.kind {
        case .adopt: "checkmark.shield.fill"
        case .create: "person.badge.key.fill"
        case .importKeyset: "shippingbox.and.arrow.backward.fill"
        case .activate: "arrow.triangle.2.circlepath"
        }
    }

    private var evidenceBadgeTitle: String {
        switch presentation.kind {
        case .adopt: "Active package"
        case .create: "Verified components"
        case .importKeyset: "Local inspection"
        case .activate: "Local inventory"
        }
    }

    private func tint(for fact: IdentityTransactionFact) -> Color {
        switch fact.state {
        case .verified: theme.colors.success
        case .attention: theme.colors.warning
        case .neutral: theme.colors.info
        }
    }

    private func symbol(for fact: IdentityTransactionFact) -> String {
        switch fact.state {
        case .verified: "checkmark"
        case .attention: "exclamationmark"
        case .neutral: "info"
        }
    }

    private func stateLabel(for state: IdentityTransactionFact.State) -> String {
        switch state {
        case .verified: "VERIFIED"
        case .attention: "REVIEW"
        case .neutral: "LOCAL"
        }
    }
}
