import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension InboundSetupAssistantView {
    @ViewBuilder
    var stepContent: some View {
        switch selectedStep {
        case .listenerProfile:
            listenerProfileStep
        case .firewall:
            firewallStep
        case .router:
            routerStep
        case .inboundProof:
            inboundProofStep
        }
    }

    private var listenerProfileStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Picker("Port profile", selection: $selectedKind) {
                Text("Recommended").tag(NetworkPortProfileKind.recommendedResidential)
                Text("Custom ports").tag(NetworkPortProfileKind.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if selectedKind == .recommendedResidential {
                VStack(alignment: .leading, spacing: 13) {
                    Label("Recommended for home routers", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.colors.success)
                    Text("The standard Quilibrium peer and streaming ports are the simplest plan to forward.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                    PortProfileRuleRow(title: "Peer traffic", port: "8336", transport: "TCP")
                    PortProfileRuleRow(title: "Protocol streaming", port: "8340", transport: "TCP")
                }
                .padding(15)
                .controlSurface(tint: theme.colors.success)
            } else {
                customPortFields
            }

            localListenerValidation

            Label(
                "This plan does not change node listeners. QuilNode can save it only after the running process already matches.",
                systemImage: "info.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(theme.colors.info)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var customPortFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Match existing node listeners")
                        .font(.subheadline.weight(.semibold))
                    Text("Use the exact ports already configured by supported Quilibrium tooling.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Button("Use defaults") { loadRecommendedProfile() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.accent)
            }

            HStack(alignment: .bottom, spacing: 12) {
                PortNumberField(title: "PEER PORT", text: $peerPortText)
                VStack(alignment: .leading, spacing: 7) {
                    Text("TRANSPORT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(theme.colors.secondaryText)
                    Picker("Peer transport", selection: $peerTransport) {
                        Text("TCP").tag(NetworkTransport.tcp)
                        Text("UDP / QUIC").tag(NetworkTransport.udp)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .frame(maxWidth: .infinity)
                PortNumberField(title: "STREAM PORT", text: $streamPortText)
            }
        }
        .padding(15)
        .controlSurface()
    }

    private var localListenerValidation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LOCAL LISTENER CHECK")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.05)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                if network.isRefreshing { ProgressView().controlSize(.small) }
                Button("Check now", systemImage: "arrow.clockwise") {
                    Task { await network.refresh() }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .disabled(network.isRefreshing)
            }

            if let inputIssue {
                VerificationRow(symbol: "exclamationmark.triangle.fill", title: inputIssue, tint: theme.colors.danger)
            } else if isReadyToActivate {
                VerificationRow(
                    symbol: "checkmark.circle.fill",
                    title: "Both listeners match this process",
                    tint: theme.colors.success
                )
            } else if let candidateProfile {
                let validation = network.validation(for: candidateProfile)
                ForEach(validation.issues, id: \.self) { issue in
                    VerificationRow(symbol: "exclamationmark.triangle.fill", title: issue, tint: theme.colors.danger)
                }
                ForEach(validation.inactiveRequirements) { requirement in
                    PortVerificationRow(requirement: requirement, tint: theme.colors.warning)
                }
            }

            if let error = network.portProfileError {
                Text(PrivacySanitizer.display(error, enabled: redactionReasons.contains(.privacy)))
                    .font(.caption)
                    .foregroundStyle(theme.colors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .controlSurface(tint: isReadyToActivate ? theme.colors.success : theme.colors.warning)
    }

    private var firewallStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            setupCallout(
                title: network.firewall.isReady ? "The installed node is allowed" : "Review the fixed operation",
                detail: network.firewall.isReady
                    ? "The application rule is active. You can continue to the manual router boundary."
                    : "QuilNode asks its pinned local service to perform only the changes listed below.",
                symbol: network.firewall.isReady ? "checkmark.shield.fill" : "shield.lefthalf.filled",
                tint: network.firewall.isReady ? theme.colors.success : theme.colors.info
            )

            VStack(alignment: .leading, spacing: 13) {
                FirewallChangeRow(
                    symbol: "firewall.fill",
                    title: "Enable macOS Application Firewall if off",
                    detail: "An already enabled firewall stays enabled."
                )
                FirewallChangeRow(
                    symbol: "app.badge.checkmark",
                    title: "Allow only the installed node binary",
                    detail: "The service resolves the fixed managed link; the app cannot provide another path."
                )
                FirewallChangeRow(
                    symbol: "arrow.triangle.2.circlepath",
                    title: "Maintain that rule after verified updates",
                    detail: "Only the prior rule recorded by QuilNode is replaced."
                )
                FirewallChangeRow(
                    symbol: "hand.raised.fill",
                    title: "Preserve every other boundary",
                    detail: "Other app rules, Block All, Stealth Mode, router settings, and credentials are untouched."
                )
            }
            .padding(15)
            .controlSurface(tint: theme.colors.info)

            if let error = network.firewallError {
                Label(
                    PrivacySanitizer.display(error, enabled: redactionReasons.contains(.privacy)),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(theme.colors.warning)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text("No router password, private key, node configuration, or unrelated firewall rule is read or retained.")
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var routerStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            setupCallout(
                title: "This step stays on your router",
                detail:
                    "QuilNode can prepare the exact plan and open a detected gateway page, but never requests router credentials.",
                symbol: "hand.raised.fill",
                tint: theme.colors.warning
            )

            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FORWARD TO THIS MAC")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1.05)
                            .foregroundStyle(theme.colors.secondaryText)
                        PrivacyProtectedText(
                            value: workspace.localAddress ?? "LAN address not detected",
                            field: .networkIdentifier
                        )
                        .font(.title3.bold().monospacedDigit())
                    }
                    Spacer()
                    Button("Copy plan", systemImage: "doc.on.doc", action: copyRouterPlan)
                        .buttonStyle(.bordered)
                }

                ForEach(workspace.portPlan.required) { requirement in
                    PortProfileRuleRow(
                        title: requirement.title,
                        port: requirement.portLabel,
                        transport: requirement.transport.rawValue
                    )
                }

                Divider().overlay(theme.colors.border.opacity(0.58))

                Label("Keep external and internal ports identical.", systemImage: "equal.circle.fill")
                Label("Forward only the listed ports to this Mac.", systemImage: "scope")
                Label("Never enable DMZ or broad port ranges.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.colors.warning)
            }
            .font(.caption)
            .padding(15)
            .controlSurface(tint: theme.colors.warning)

            if workspace.routerAccess.browserURL != nil {
                Button("Open detected gateway page", systemImage: "safari", action: openGateway)
                    .buttonStyle(.bordered)
            } else {
                Text(workspace.routerAccess.detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
    }

    private var inboundProofStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            setupCallout(
                title: workspace.inboundEvidence ? "Inbound traffic observed" : "Waiting for remote peer traffic",
                detail: workspace.inboundEvidence
                    ? "A connection crossed the local network boundary and reached this process."
                    : "Keep the node running. This view updates from local sockets and node counters; no remote port checker is used.",
                symbol: workspace.inboundEvidence ? "checkmark.seal.fill" : "clock.arrow.circlepath",
                tint: workspace.inboundEvidence ? theme.colors.success : theme.colors.info
            )

            VStack(alignment: .leading, spacing: 12) {
                evidenceChecklistRow(
                    title: "Node listeners",
                    detail: workspace.stage(.listeners).status,
                    complete: workspace.stage(.listeners).state == .verified
                )
                evidenceChecklistRow(
                    title: "macOS firewall",
                    detail: workspace.stage(.firewall).status,
                    complete: workspace.firewall.isReady
                )
                evidenceChecklistRow(
                    title: "Router boundary",
                    detail: workspace.inboundEvidence ? "Proven by traffic" : "Manual rules not proven yet",
                    complete: workspace.inboundEvidence
                )
                evidenceChecklistRow(
                    title: "Inbound connection",
                    detail: workspace.inboundEvidence ? "Observed locally" : "No local event yet",
                    complete: workspace.inboundEvidence
                )
            }
            .padding(15)
            .controlSurface(tint: workspace.inboundEvidence ? theme.colors.success : theme.colors.info)

            Text(
                workspace.inboundEvidence
                    ? "The router plan is now supported by local evidence."
                    : "Settings alone never count as success. Evidence may arrive after a peer reconnects."
            )
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func setupCallout(title: String, detail: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func evidenceChecklistRow(title: String, detail: String, complete: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(complete ? theme.colors.success : theme.colors.secondaryText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
