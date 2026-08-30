import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct PortProfileEditorView: View {
    @EnvironmentObject private var network: NetworkReadinessCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    @State private var selectedKind: NetworkPortProfileKind
    @State private var peerPortText: String
    @State private var streamPortText: String
    @State private var peerTransport: NetworkTransport

    init(profile: NetworkPortProfile) {
        _selectedKind = State(initialValue: profile.kind)
        _peerPortText = State(initialValue: String(profile.peerPort))
        _streamPortText = State(initialValue: String(profile.streamPort))
        _peerTransport = State(initialValue: profile.peerTransport == .udp ? .udp : .tcp)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profilePicker
                    if selectedKind == .recommendedResidential {
                        recommendedSummary
                    } else {
                        customFields
                    }
                    verificationCard
                    safetyBoundary
                }
                .padding(22)
            }
            Divider()
            footer
        }
        .frame(width: 610, height: 650)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .onChange(of: selectedKind) { _, kind in
            network.clearPortProfileError()
            if kind == .recommendedResidential {
                let defaults = NetworkPortProfile.recommendedResidential
                peerPortText = String(defaults.peerPort)
                streamPortText = String(defaults.streamPort)
                peerTransport = defaults.peerTransport
            }
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            DashboardCircleIcon(
                systemImage: "point.3.connected.trianglepath.dotted", tint: theme.colors.accent, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("Node port profile").font(.title2.bold())
                Text("The router plan only changes after the live node listeners match.")
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(22)
    }

    private var profilePicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("PROFILE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(theme.colors.secondaryText)
            Picker("Port profile", selection: $selectedKind) {
                Text("Recommended").tag(NetworkPortProfileKind.recommendedResidential)
                Text("Custom").tag(NetworkPortProfileKind.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var recommendedSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommended for home routers", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(theme.colors.success)
            Text(
                "Quilibrium’s residential guidance uses TCP for both master listeners. These defaults are easiest to forward and remain the QuilNode default."
            )
            .font(.subheadline)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            PortProfileRuleRow(title: "Peer traffic", port: "8336", transport: "TCP")
            PortProfileRuleRow(title: "Protocol streaming", port: "8340", transport: "TCP")
        }
        .padding(16)
        .controlSurface(tint: theme.colors.success)
    }

    private var customFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom listener pair").font(.headline)
                    Text("Use the exact ports already configured on the node.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Button("Use defaults") {
                    let defaults = NetworkPortProfile.recommendedResidential
                    peerPortText = String(defaults.peerPort)
                    streamPortText = String(defaults.streamPort)
                    peerTransport = defaults.peerTransport
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.accent)
            }

            HStack(spacing: 12) {
                PortNumberField(title: "PEER PORT", text: $peerPortText)
                VStack(alignment: .leading, spacing: 7) {
                    Text("PEER TRANSPORT")
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

            Text(
                "External and internal ports stay identical. Changing only the router’s external port can break peer discovery unless the node also advertises that mapping."
            )
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .controlSurface()
    }

    private var verificationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("LIVE VERIFICATION")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
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
            } else if let candidateProfile {
                let validation = network.validation(for: candidateProfile)
                if validation.isReadyToActivate {
                    VerificationRow(
                        symbol: "checkmark.circle.fill", title: "Both listeners match this process",
                        tint: theme.colors.success)
                } else {
                    ForEach(validation.issues, id: \.self) { issue in
                        VerificationRow(
                            symbol: "exclamationmark.triangle.fill", title: issue, tint: theme.colors.danger)
                    }
                    ForEach(validation.inactiveRequirements) { requirement in
                        PortVerificationRow(
                            requirement: requirement,
                            tint: theme.colors.warning
                        )
                    }
                }
            }

            if let error = network.portProfileError {
                Text(PrivacySanitizer.display(error, enabled: redactionReasons.contains(.privacy)))
                    .font(.caption)
                    .foregroundStyle(theme.colors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .controlSurface(tint: validationTint)
    }

    private var safetyBoundary: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(theme.colors.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text("Self-custody boundary").font(.subheadline.weight(.semibold))
                Text(
                    "QuilNode verifies process listeners and saves only this non-secret profile. It does not open or rewrite the root-owned node config, which also contains identity material. Configure a custom listener through Quilibrium’s supported tooling, restart the node, then activate the matching plan here."
                )
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            theme.colors.surfaceElevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Text("Active: \(network.activePortProfile.title)")
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Verify & activate", systemImage: "checkmark.shield") {
                guard let candidateProfile else { return }
                if network.activatePortProfile(candidateProfile) { dismiss() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isReadyToActivate)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private var candidateProfile: NetworkPortProfile? {
        if selectedKind == .recommendedResidential { return .recommendedResidential }
        guard let peer = UInt16(peerPortText), let stream = UInt16(streamPortText) else { return nil }
        return NetworkPortProfile(kind: .custom, peerPort: peer, peerTransport: peerTransport, streamPort: stream)
    }

    private var inputIssue: String? {
        guard let peer = Int(peerPortText), let stream = Int(streamPortText) else {
            return "Enter a whole port number from 1024 through 65535."
        }
        guard (1_024...65_535).contains(peer), (1_024...65_535).contains(stream) else {
            return "Use ports from 1024 through 65535."
        }
        guard peer != stream else { return "Peer traffic and streaming need different ports." }
        return nil
    }

    private var isReadyToActivate: Bool {
        guard inputIssue == nil, let candidateProfile else { return false }
        return network.validation(for: candidateProfile).isReadyToActivate
    }

    private var validationTint: Color {
        isReadyToActivate ? theme.colors.success : theme.colors.warning
    }
}
