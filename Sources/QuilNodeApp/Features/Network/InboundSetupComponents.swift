import SwiftUI

struct InboundSetupStepRail: View {
    @Environment(\.quilTheme) private var theme

    let steps: [InboundSetupStepPresentation]
    @Binding var selection: InboundSetupStep

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, item in
                Button {
                    selection = item.step
                } label: {
                    HStack(alignment: .top, spacing: 11) {
                        ZStack {
                            Circle()
                                .fill(circleFill(for: item))
                                .frame(width: 28, height: 28)
                            Text(item.step.ordinal.formatted())
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(circleText(for: item))
                        }
                        .overlay {
                            Circle().stroke(stateTint(item.state).opacity(0.7), lineWidth: 1)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Label(item.step.title, systemImage: item.step.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.colors.primaryText)
                            Text(item.step.shortDetail)
                                .font(.caption2)
                                .foregroundStyle(theme.colors.secondaryText)
                            InboundSetupStateBadge(state: item.state)
                                .padding(.top, 4)
                        }

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(selection == item.step ? theme.colors.selection.opacity(0.5) : Color.clear)
                    .overlay(alignment: .leading) {
                        if selection == item.step {
                            Rectangle()
                                .fill(theme.colors.accent)
                                .frame(width: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(item.step.ordinal), \(item.step.title), \(item.state.label)")

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(theme.colors.border.opacity(0.7))
                        .frame(width: 1, height: 12)
                        .padding(.leading, 28)
                }
            }
            Spacer(minLength: 16)
        }
        .frame(width: 214, alignment: .topLeading)
        .background(theme.colors.sidebar.opacity(0.48))
    }

    private func circleFill(for item: InboundSetupStepPresentation) -> Color {
        if selection == item.step { return theme.colors.accent }
        return stateTint(item.state).opacity(item.state == .verified ? 0.2 : 0.1)
    }

    private func circleText(for item: InboundSetupStepPresentation) -> Color {
        selection == item.step ? Color.white : stateTint(item.state)
    }

    private func stateTint(_ state: InboundSetupEvidenceState) -> Color {
        switch state {
        case .verified: theme.colors.success
        case .needsAction: theme.colors.info
        case .manual: theme.colors.warning
        case .waiting: theme.colors.secondaryText
        }
    }
}

struct InboundSetupStateBadge: View {
    @Environment(\.quilTheme) private var theme

    let state: InboundSetupEvidenceState

    var body: some View {
        Text(state.label.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.55)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(tint.opacity(0.1), in: Capsule())
    }

    private var tint: Color {
        switch state {
        case .verified: theme.colors.success
        case .needsAction: theme.colors.info
        case .manual: theme.colors.warning
        case .waiting: theme.colors.secondaryText
        }
    }
}

struct InboundSetupEvidencePanel: View {
    @Environment(\.quilTheme) private var theme

    let step: InboundSetupStep
    let workspace: NetworkWorkspacePresentation
    let isRefreshing: Bool
    let refresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("LOCAL EVIDENCE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(theme.colors.secondaryText)
                Text("Proof from this Mac")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }

            Divider().overlay(theme.colors.border.opacity(0.55))

            Label(evidenceTitle, systemImage: evidenceSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(evidenceTint)

            Text(evidenceDetail)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(evidenceRows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.label)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                        PrivacyProtectedText(value: row.value, field: row.privacyField)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .lineLimit(2)
                    }
                }
            }

            Button(isRefreshing ? "Checking…" : "Check now", systemImage: "arrow.clockwise", action: refresh)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .frame(width: 210, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(theme.colors.surfaceElevated.opacity(0.34))
    }

    private var evidenceStage: NetworkStagePresentation {
        switch step {
        case .listenerProfile: workspace.stage(.listeners)
        case .firewall: workspace.stage(.firewall)
        case .router: workspace.stage(.gateway)
        case .inboundProof: workspace.stage(.internetBoundary)
        }
    }

    private var evidenceTitle: String {
        switch step {
        case .listenerProfile: "Listener verification"
        case .firewall: "Application rule"
        case .router: "Gateway route"
        case .inboundProof: workspace.inboundEvidence ? "Inbound observed" : "Awaiting inbound"
        }
    }

    private var evidenceSymbol: String {
        switch evidenceStage.state {
        case .verified: "checkmark.seal.fill"
        case .active: "bolt.horizontal.circle.fill"
        case .review: "exclamationmark.circle.fill"
        case .blocked: "xmark.octagon.fill"
        case .waiting: "clock.fill"
        }
    }

    private var evidenceTint: Color {
        evidenceStage.state.tint(in: theme)
    }

    private var evidenceDetail: String {
        evidenceStage.detail
    }

    private var evidenceRows: [InboundSetupEvidenceRow] {
        let observed = evidenceStage.observedAt.map(NetworkFreshnessFormatter.string) ?? "Evidence pending"
        switch step {
        case .listenerProfile:
            return [
                .init(label: "Observed listeners", value: evidenceStage.value, privacyField: .networkPort),
                .init(label: "Source", value: evidenceStage.evidenceSource),
                .init(label: "Observed", value: observed),
            ]
        case .firewall:
            return [
                .init(label: "Current rule", value: evidenceStage.value),
                .init(label: "Source", value: evidenceStage.evidenceSource),
                .init(label: "Observed", value: observed),
            ]
        case .router:
            return [
                .init(
                    label: "Gateway", value: workspace.gatewayAddress ?? "Not detected",
                    privacyField: .networkIdentifier),
                .init(
                    label: "This Mac", value: workspace.localAddress ?? "Not detected", privacyField: .networkIdentifier
                ),
                .init(label: "Observed", value: observed),
            ]
        case .inboundProof:
            return [
                .init(
                    label: "Boundary state",
                    value: workspace.inboundEvidence ? "Observed locally" : "Not observed yet",
                    privacyField: .networkActivity
                ),
                .init(label: "Source", value: evidenceStage.evidenceSource),
                .init(label: "Remote checker", value: "Not used"),
            ]
        }
    }
}

private struct InboundSetupEvidenceRow: Identifiable {
    let label: String
    let value: String
    var privacyField: PrivacyField?

    var id: String { label }
}

struct InboundSetupCustodyBoundary: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(theme.colors.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text("Self-custody boundary")
                    .font(.caption.weight(.semibold))
                Text(
                    "QuilNode saves only a non-secret port plan. It never reads or rewrites the root-owned node config, router credentials, or private keys."
                )
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(theme.colors.info.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.colors.info.opacity(0.18), lineWidth: 1)
        }
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
