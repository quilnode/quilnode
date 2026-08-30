import SwiftUI

struct NetworkStageInspector: View {
    @Environment(\.quilTheme) private var theme

    let presentation: NetworkWorkspacePresentation
    let selectedStage: NetworkStageKind
    let isConfiguringFirewall: Bool
    let firewallError: String?
    let openGateway: () -> Void
    let copyValue: (String?) -> Void
    let customizePorts: () -> Void
    let configureFirewall: () -> Void
    let openFirewallSettings: () -> Void

    private var stage: NetworkStagePresentation {
        presentation.stage(selectedStage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(theme.colors.border.opacity(0.66))

            VStack(alignment: .leading, spacing: 14) {
                statusSection
                Divider().overlay(theme.colors.border.opacity(0.52))
                evidenceSection
                Divider().overlay(theme.colors.border.opacity(0.52))
                actionSection
                Spacer(minLength: 8)
                privacyBoundary
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 580, alignment: .topLeading)
        .controlSurface()
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected stage")
                .font(.headline)
            HStack(spacing: 10) {
                DashboardCircleIcon(
                    systemImage: stage.kind.symbol,
                    tint: stage.state.tint(in: theme),
                    size: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.kind.title)
                        .font(.title3.bold())
                    Text(stage.evidenceSource)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
        .padding(14)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            NetworkInspectorLabel("Status")
            HStack {
                NetworkStateBadge(state: stage.state, label: stage.status)
                Spacer()
                Text(stage.observedAt.map(NetworkFreshnessFormatter.string) ?? "Evidence pending")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Text(stage.detail)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            NetworkInspectorLabel("Local evidence")
            switch selectedStage {
            case .listeners:
                ForEach(presentation.portPlan.required) { requirement in
                    valueRow(
                        label: requirement.title,
                        value: "\(requirement.portLabel)  \(requirement.transport.rawValue)",
                        privacyField: .networkPort,
                        copyable: requirement.portLabel
                    )
                }
            case .firewall:
                valueRow(label: "Application rule", value: stage.value)
                valueRow(
                    label: "Stealth mode",
                    value: presentation.firewall.stealthEnabled ? "On" : "Off"
                )
                valueRow(
                    label: "Maintained by QuilNode",
                    value: presentation.firewall.managedByQuilNode ? "Yes" : "No"
                )
            case .gateway:
                valueRow(
                    label: "Detected gateway",
                    value: presentation.gatewayAddress ?? "Not detected",
                    privacyField: .networkIdentifier,
                    copyable: presentation.gatewayAddress
                )
                valueRow(
                    label: "This Mac on LAN",
                    value: presentation.localAddress ?? "Not detected",
                    privacyField: .networkIdentifier,
                    copyable: presentation.localAddress
                )
                valueRow(label: "Active interface", value: presentation.interfaceLabel)
                ForEach(presentation.portPlan.required) { requirement in
                    valueRow(
                        label: requirement.title,
                        value: "\(requirement.portLabel)  \(requirement.transport.rawValue)",
                        privacyField: .networkPort,
                        copyable: requirement.portLabel
                    )
                }
            case .internetBoundary:
                valueRow(
                    label: "Inbound proof",
                    value: presentation.inboundEvidence ? "Observed locally" : "Not observed yet",
                    privacyField: .networkActivity
                )
                valueRow(label: "Remote probe", value: "Not used")
            case .inboundPeers:
                valueRow(
                    label: "Current peer mesh",
                    value: stage.value,
                    privacyField: .networkActivity
                )
                valueRow(
                    label: "Inbound boundary",
                    value: presentation.inboundEvidence ? "Proven" : "Not proven yet",
                    privacyField: .networkActivity
                )
            }
        }
    }

    @ViewBuilder
    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            NetworkInspectorLabel("Safe next action")

            switch selectedStage {
            case .listeners:
                if stage.state == .verified {
                    noAction("Every required local listener is active.")
                } else {
                    actionButton("Review port profile", symbol: "slider.horizontal.3", action: customizePorts)
                }
            case .firewall:
                if presentation.firewall.isReady {
                    noAction("The installed node binary is explicitly allowed.")
                } else {
                    actionButton(
                        isConfiguringFirewall ? "Applying…" : "Configure node access",
                        symbol: "checkmark.shield",
                        action: configureFirewall,
                        disabled: isConfiguringFirewall
                    )
                    Button("Open System Settings…", action: openFirewallSettings)
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(theme.colors.accent)
                    if let firewallError {
                        Label(firewallError, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.colors.warning)
                    }
                }
            case .gateway:
                if presentation.inboundEvidence {
                    noAction("Inbound traffic proves the current path is working.")
                }
                if presentation.routerAccess.browserURL != nil {
                    if presentation.inboundEvidence {
                        Button("Open gateway page", systemImage: "safari", action: openGateway)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    } else {
                        Button("Open gateway page", systemImage: "safari", action: openGateway)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                } else {
                    Text(presentation.routerAccess.detail)
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Label(
                    "Forward only the listed ports. Never enable DMZ or broad ranges.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2)
                .foregroundStyle(theme.colors.warning)
                .fixedSize(horizontal: false, vertical: true)
            case .internetBoundary:
                if presentation.inboundEvidence {
                    noAction("Remote traffic has crossed the local network boundary.")
                } else {
                    Label("Keep the node running while local evidence arrives.", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(theme.colors.info)
                }
            case .inboundPeers:
                noAction("Peer count is contextual; inbound proof is evaluated separately.")
            }
        }
    }

    private var privacyBoundary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Local-only boundary", systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.success)
            Text(
                "Addresses, ports, and network activity are masked by Privacy Mode. Copy actions remain available to the operator."
            )
            .font(.caption2)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(theme.colors.surfaceElevated.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private func valueRow(
        label: String,
        value: String,
        privacyField: PrivacyField? = nil,
        copyable: String? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 4)
            if let copyable {
                Button {
                    copyValue(copyable)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .help("Copy \(label.lowercased())")
            }
        }
    }

    private func actionButton(
        _ title: String,
        symbol: String,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> some View {
        Button(title, systemImage: symbol, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(disabled)
    }

    private func noAction(_ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No action needed", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.success)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NetworkInspectorLabel: View {
    @Environment(\.quilTheme) private var theme
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(theme.colors.secondaryText)
    }
}
