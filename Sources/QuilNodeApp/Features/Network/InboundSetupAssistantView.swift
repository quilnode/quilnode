import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// One evidence-driven journey for the three different boundaries involved in
/// inbound connectivity: the node process, this Mac, and the operator's router.
/// Only local observations can mark the final boundary as verified.
struct InboundSetupAssistantView: View {
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject var network: NetworkReadinessCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) var theme
    @Environment(\.quilMotion) private var motion
    @Environment(\.redactionReasons) var redactionReasons

    @State var selectedStep: InboundSetupStep
    @State var selectedKind: NetworkPortProfileKind
    @State var peerPortText: String
    @State var streamPortText: String
    @State var peerTransport: NetworkTransport
    private let previewWorkspace: NetworkWorkspacePresentation?
    private let previewProfileReady: Bool?

    init(initialStep: InboundSetupStep) {
        previewWorkspace = nil
        previewProfileReady = nil
        _selectedStep = State(initialValue: initialStep)
        _selectedKind = State(initialValue: .recommendedResidential)
        _peerPortText = State(initialValue: String(NetworkPortProfile.recommendedResidential.peerPort))
        _streamPortText = State(initialValue: String(NetworkPortProfile.recommendedResidential.streamPort))
        _peerTransport = State(initialValue: NetworkPortProfile.recommendedResidential.peerTransport)
    }

    #if DEBUG
        init(
            previewWorkspace: NetworkWorkspacePresentation,
            initialStep: InboundSetupStep = .listenerProfile,
            profileKind: NetworkPortProfileKind = .recommendedResidential
        ) {
            self.previewWorkspace = previewWorkspace
            previewProfileReady = true
            _selectedStep = State(initialValue: initialStep)
            _selectedKind = State(initialValue: profileKind)
            _peerPortText = State(initialValue: String(NetworkPortProfile.recommendedResidential.peerPort))
            _streamPortText = State(initialValue: String(NetworkPortProfile.recommendedResidential.streamPort))
            _peerTransport = State(initialValue: NetworkPortProfile.recommendedResidential.peerTransport)
        }
    #endif

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.colors.border.opacity(0.72))

            HStack(spacing: 0) {
                InboundSetupStepRail(steps: steps, selection: $selectedStep)
                Divider().overlay(theme.colors.border.opacity(0.62))

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stepHeader
                        stepContent
                        InboundSetupCustodyBoundary()
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(theme.colors.border.opacity(0.62))
                InboundSetupEvidencePanel(
                    step: selectedStep,
                    workspace: workspace,
                    isRefreshing: network.isRefreshing,
                    refresh: { Task { await network.refresh(forceRouterProbe: selectedStep == .router) } }
                )
            }

            Divider().overlay(theme.colors.border.opacity(0.72))
            footer
        }
        .frame(width: 980, height: 730)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .onAppear {
            if previewWorkspace == nil { loadActiveProfile() }
        }
        .onChange(of: selectedKind) { _, kind in
            network.clearPortProfileError()
            guard kind == .recommendedResidential else { return }
            loadRecommendedProfile()
        }
        .animation(motion.selection, value: selectedStep)
    }

    var workspace: NetworkWorkspacePresentation {
        if let previewWorkspace { return previewWorkspace }
        return .make(
            snapshot: monitor.snapshot,
            assessment: network.assessment,
            inspection: network.inspection,
            gateway: network.gatewayRoute,
            routerAccess: network.routerAccess,
            firewall: network.firewall,
            portPlan: network.portPlan
        )
    }

    private var steps: [InboundSetupStepPresentation] {
        InboundSetupPresentation.steps(from: workspace)
    }

    private var header: some View {
        HStack(spacing: 13) {
            DashboardCircleIcon(
                systemImage: "point.3.connected.trianglepath.dotted",
                tint: theme.colors.success,
                size: 44
            )
            VStack(alignment: .leading, spacing: 3) {
                Text("Inbound setup")
                    .font(.title2.bold())
                Text("Build a safe path, then verify it from local evidence.")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
            Label("Local-only setup", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.colors.surfaceElevated.opacity(0.72), in: Capsule())
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close inbound setup")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
    }

    private var stepHeader: some View {
        HStack(alignment: .top, spacing: 13) {
            DashboardCircleIcon(
                systemImage: selectedStep.symbol,
                tint: selectedStepTint,
                size: 46
            )
            VStack(alignment: .leading, spacing: 3) {
                Text("STEP \(selectedStep.ordinal) OF \(InboundSetupStep.allCases.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.05)
                    .foregroundStyle(theme.colors.accent)
                Text(selectedStep.title)
                    .font(.title2.bold())
                Text(stepSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Text("Active profile: \(network.activePortProfile.title)")
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer()
            Button(primaryActionTitle, systemImage: primaryActionSymbol, action: performPrimaryAction)
                .buttonStyle(.borderedProminent)
                .disabled(primaryActionDisabled)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var stepSubtitle: String {
        switch selectedStep {
        case .listenerProfile: "Match a router plan to listeners already active on this node."
        case .firewall: "Review the exact local change before allowing the node binary."
        case .router: "Apply the prepared forwarding rules yourself on the detected gateway."
        case .inboundProof: "Let local evidence—not configuration—close the final boundary."
        }
    }

    private var selectedStepTint: Color {
        guard let item = steps.first(where: { $0.step == selectedStep }) else { return theme.colors.accent }
        return switch item.state {
        case .verified: theme.colors.success
        case .needsAction: theme.colors.info
        case .manual: theme.colors.warning
        case .waiting: theme.colors.secondaryText
        }
    }

    private var primaryActionTitle: String {
        return switch selectedStep {
        case .listenerProfile: "Continue to macOS firewall"
        case .firewall:
            network.isConfiguringFirewall
                ? "Applying…"
                : (network.firewall.isReady ? "Continue to router" : "Enable & allow node")
        case .router: "Wait for inbound proof"
        case .inboundProof: network.isRefreshing ? "Checking…" : "Check for inbound traffic"
        }
    }

    private var primaryActionSymbol: String {
        switch selectedStep {
        case .listenerProfile: "arrow.right"
        case .firewall: network.firewall.isReady ? "arrow.right" : "checkmark.shield"
        case .router: "clock.arrow.circlepath"
        case .inboundProof: "arrow.clockwise"
        }
    }

    private var primaryActionDisabled: Bool {
        switch selectedStep {
        case .listenerProfile: !isReadyToActivate
        case .firewall: network.isConfiguringFirewall
        case .router: false
        case .inboundProof: network.isRefreshing
        }
    }

    private func performPrimaryAction() {
        switch selectedStep {
        case .listenerProfile:
            guard let candidateProfile, network.activatePortProfile(candidateProfile) else { return }
            selectedStep = .firewall
        case .firewall:
            if network.firewall.isReady {
                selectedStep = .router
            } else {
                Task {
                    await network.configureFirewall()
                    if network.firewall.isReady { selectedStep = .router }
                }
            }
        case .router:
            selectedStep = .inboundProof
            Task { await network.refresh(forceRouterProbe: true) }
        case .inboundProof:
            Task { await network.refresh(forceRouterProbe: true) }
        }
    }

    var candidateProfile: NetworkPortProfile? {
        if selectedKind == .recommendedResidential { return .recommendedResidential }
        guard let peer = UInt16(peerPortText), let stream = UInt16(streamPortText) else { return nil }
        return NetworkPortProfile(
            kind: .custom,
            peerPort: peer,
            peerTransport: peerTransport,
            streamPort: stream
        )
    }

    var inputIssue: String? {
        guard let peer = Int(peerPortText), let stream = Int(streamPortText) else {
            return "Enter whole port numbers from 1024 through 65535."
        }
        guard (1_024...65_535).contains(peer), (1_024...65_535).contains(stream) else {
            return "Use ports from 1024 through 65535."
        }
        guard peer != stream else { return "Peer traffic and streaming need different ports." }
        return nil
    }

    var isReadyToActivate: Bool {
        guard inputIssue == nil, let candidateProfile else { return false }
        if let previewProfileReady { return previewProfileReady }
        return network.validation(for: candidateProfile).isReadyToActivate
    }

    private func loadActiveProfile() {
        let profile = network.activePortProfile
        selectedKind = profile.kind
        peerPortText = String(profile.peerPort)
        streamPortText = String(profile.streamPort)
        peerTransport = profile.peerTransport == .udp ? .udp : .tcp
    }

    func loadRecommendedProfile() {
        let profile = NetworkPortProfile.recommendedResidential
        peerPortText = String(profile.peerPort)
        streamPortText = String(profile.streamPort)
        peerTransport = profile.peerTransport
    }

    func copyRouterPlan() {
        let target = workspace.localAddress ?? "THIS_MAC_LAN_IP"
        let rules = workspace.portPlan.required.map {
            "\($0.portLabel) \($0.transport.rawValue) → \(target), same internal and external port"
        }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            "QuilNode router plan (\(network.activePortProfile.title))\nReserve \(target) with DHCP\n\(rules)\nNever enable DMZ or broad port ranges.",
            forType: .string
        )
    }

    func openGateway() {
        guard let url = workspace.routerAccess.browserURL else { return }
        NSWorkspace.shared.open(url)
    }
}
