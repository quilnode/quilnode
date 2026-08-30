import SwiftUI

struct IdentityTransactionPlanRail: View {
    @Environment(\.quilTheme) private var theme

    let stages: [IdentityTransactionStage]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                stageNode(stage, isReady: index == 0)
                if index < stages.count - 1 {
                    Capsule()
                        .fill(theme.colors.border.opacity(0.56))
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                        .padding(.top, 15)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Protected identity transaction plan")
    }

    private func stageNode(_ stage: IdentityTransactionStage, isReady: Bool) -> some View {
        let tint = isReady ? theme.colors.accent : theme.colors.secondaryText
        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(tint.opacity(isReady ? 0.16 : 0.07))
                Circle()
                    .strokeBorder(tint.opacity(isReady ? 0.92 : 0.38), lineWidth: isReady ? 2 : 1)
                Text("\(stage.number)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(tint)
            }
            .frame(width: 31, height: 31)

            Text(stage.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isReady ? theme.colors.primaryText : theme.colors.secondaryText)
            Text(stage.detail)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: 84)
    }
}

struct IdentityTransactionDossier: View {
    @Environment(\.quilTheme) private var theme

    let presentation: IdentityTransactionPresentation
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                DashboardCircleIcon(
                    systemImage: dossierSymbol,
                    tint: theme.colors.success,
                    size: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.headline)
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

struct IdentityTransactionBoundary: View {
    @Environment(\.quilTheme) private var theme

    let changes: [IdentityTransactionContractItem]
    let untouched: [IdentityTransactionContractItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Transaction boundary")
                    .font(.headline)
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
                        Text(item.title)
                            .font(.caption.weight(.semibold))
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

struct IdentityTransactionTimeline: View {
    @Environment(\.quilTheme) private var theme

    let moments: [IdentityTransactionMoment]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: moment.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index == 1 ? theme.colors.accent : theme.colors.success)
                        .frame(width: 26, height: 26)
                        .background(
                            (index == 1 ? theme.colors.accent : theme.colors.success).opacity(0.09),
                            in: Circle()
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(moment.title)
                            .font(.caption.weight(.semibold))
                        Text(moment.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

                if index < moments.count - 1 {
                    Divider().frame(height: 42)
                }
            }
        }
        .padding(.vertical, 8)
        .controlSurface(tint: theme.colors.info)
    }
}

struct IdentityDispositionPicker: View {
    @Environment(\.quilTheme) private var theme

    @Binding var selection: IdentityImportDisposition

    var body: some View {
        HStack(spacing: 10) {
            choice(
                .activate,
                title: "Activate after import",
                detail: "Import, protect, switch, and verify in one confirmed sequence.",
                symbol: "bolt.fill",
                badge: "Recommended"
            )
            choice(
                .recoveryOnly,
                title: "Add to recovery only",
                detail: "Store the verified package for a later protected switch.",
                symbol: "archivebox.fill",
                badge: nil
            )
        }
    }

    private func choice(
        _ value: IdentityImportDisposition,
        title: String,
        detail: String,
        symbol: String,
        badge: String?
    ) -> some View {
        Button {
            selection = value
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selection == value ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selection == value ? theme.colors.accent : theme.colors.secondaryText)
                DashboardCircleIcon(
                    systemImage: symbol,
                    tint: selection == value ? theme.colors.accent : theme.colors.secondaryText,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.caption.weight(.semibold))
                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .tracking(0.45)
                                .foregroundStyle(theme.colors.accent)
                        }
                    }
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .frame(maxWidth: .infinity)
        .background(theme.colors.surface.opacity(selection == value ? 0.88 : 0.52))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    selection == value ? theme.colors.accent.opacity(0.86) : theme.colors.border.opacity(0.44),
                    lineWidth: selection == value ? 1.2 : 0.6
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
        .quilHoverSurface(tint: theme.colors.accent, cornerRadius: theme.metrics.controlCornerRadius)
    }
}
