import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkReadinessView: View {
    @EnvironmentObject var monitor: NodeMonitor
    @EnvironmentObject var network: NetworkReadinessCoordinator
    @Environment(\.quilTheme) var theme
    @State var showingFirewallConfirmation = false
    @State var showingPortEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            readinessHero
            evidenceStrip
            firewallGuide
            routerGuide
            clusterDisclosure
        }
        .sheet(isPresented: $showingFirewallConfirmation) {
            FirewallConfirmationView {
                showingFirewallConfirmation = false
                Task { await network.configureFirewall() }
            }
        }
        .sheet(isPresented: $showingPortEditor) {
            PortProfileEditorView(profile: network.activePortProfile)
        }
    }

    private var readinessHero: some View {
        HStack(spacing: 18) {
            DashboardCircleIcon(
                systemImage: statusSymbol,
                tint: statusColor,
                size: 58
            )
            VStack(alignment: .leading, spacing: 5) {
                Text("NETWORK READINESS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(statusColor)
                Text(network.assessment.title)
                    .font(
                        .system(
                            size: 26 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign))
                Text(network.assessment.detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Button {
                Task { await network.refresh(forceRouterProbe: true) }
            } label: {
                if network.isRefreshing {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Checking…")
                    }
                } else {
                    Label("Check again", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(network.isRefreshing)
        }
        .padding(20)
        .controlSurface(tint: statusColor)
    }

    private var evidenceStrip: some View {
        HStack(spacing: 12) {
            NetworkEvidenceTile(
                icon: "dot.radiowaves.left.and.right",
                title: "LOCAL LISTENERS",
                value: listenerValue,
                detail: listenerDetail,
                tint: listenersHealthy ? theme.colors.success : theme.colors.warning,
                privacyField: .networkPort
            )
            NetworkEvidenceTile(
                icon: "arrow.down.left.and.arrow.up.right",
                title: "INBOUND PEERS",
                value: inboundValue,
                detail: inboundDetail,
                tint: hasInboundEvidence
                    ? theme.colors.success : theme.colors.info,
                privacyField: .networkActivity
            )
            NetworkEvidenceTile(
                icon: "firewall.fill",
                title: "MAC FIREWALL",
                value: firewallValue,
                detail: firewallDetail,
                tint: firewallTint
            )
        }
    }

    private var routerGuide: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                DashboardCircleIcon(systemImage: "wifi.router.fill", tint: theme.colors.accent, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Router setup")
                        .font(.title3.bold())
                    Text("A one-time manual step for residential connections")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Text(network.activePortProfile.title.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(theme.colors.accent.opacity(0.11), in: Capsule())
                Button("Customize", systemImage: "slider.horizontal.3") {
                    network.clearPortProfileError()
                    showingPortEditor = true
                }
                .buttonStyle(.bordered)
                Button("Copy plan", systemImage: "doc.on.doc") { copyPlan() }
                    .buttonStyle(.bordered)
            }

            gatewayAccess

            HStack(spacing: 12) {
                routerTarget
                portRules
            }

            VStack(alignment: .leading, spacing: 11) {
                RouterInstructionRow(
                    number: 1,
                    title: "Keep this Mac on the same LAN address",
                    detail:
                        "Create a DHCP reservation for the Mac in your router. If its address changes, old forwarding rules point at the wrong device."
                )
                RouterInstructionRow(
                    number: 2,
                    title: "Add the two forwarding rules shown above",
                    detail:
                        "Use the router's web page or manufacturer app. Keep external and internal ports identical, use the transport shown for each rule, and set the destination to this Mac. Labels may say Port Forwarding, NAT, Virtual Server, or Gaming."
                )
                RouterInstructionRow(
                    number: 3,
                    title: "Save or apply, without enabling DMZ",
                    detail:
                        "Do not expose every port and do not give QuilNode your router password. Only the node ports should be forwarded."
                )
                RouterInstructionRow(
                    number: 4,
                    title: "Leave the node running while evidence arrives",
                    detail:
                        "QuilNode checks the official node's own libp2p metrics. A remote port-check website is not required."
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(theme.colors.success)
                Text(
                    "QuilNode never reads or stores router credentials, never enables UPnP, and never changes your router automatically."
                )
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                Spacer()
            }
        }
        .padding(18)
        .controlSurface()
    }

    private var firewallGuide: some View {
        HStack(alignment: .top, spacing: 16) {
            DashboardCircleIcon(
                systemImage: firewallStatusSymbol,
                tint: firewallTint,
                size: 44
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Protect this Mac")
                        .font(.title3.bold())
                    Text(firewallStatusLabel.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(firewallTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(firewallTint.opacity(0.12), in: Capsule())
                }
                Text(firewallGuideDetail)
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    FirewallPromise(symbol: "checkmark.shield", text: "Preserves existing rules")
                    FirewallPromise(symbol: "app.badge.checkmark", text: "Allows the current node")
                    FirewallPromise(symbol: "arrow.triangle.2.circlepath", text: "Refreshes after updates")
                }
                .padding(.top, 3)
                if let error = network.firewallError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.colors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 8) {
                Button(firewallActionTitle, systemImage: firewallActionSymbol) {
                    performFirewallAction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(network.isConfiguringFirewall)
                if network.isConfiguringFirewall {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Configuring macOS Firewall")
                } else {
                    Button("System Settings…") { openFirewallSettings() }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.colors.accent)
                        .font(.caption)
                }
            }
        }
        .padding(18)
        .controlSurface(tint: firewallTint)
    }

    private var gatewayAccess: some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardCircleIcon(
                systemImage: gatewayStatusSymbol,
                tint: gatewayStatusColor,
                size: 40
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("DETECTED DEFAULT GATEWAY")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(theme.colors.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    PrivacyProtectedText(
                        value: network.gatewayRoute.address ?? "Not detected",
                        field: .networkIdentifier
                    )
                    .font(.title3.bold().monospaced())
                    Text(gatewayInterfaceLabel)
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Text(network.routerAccess.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(gatewayStatusColor)
                Text(network.routerAccess.detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Button {
                copy(network.gatewayRoute.address)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(network.gatewayRoute.address == nil)
            .help("Copy the default gateway address")

            Button(routerActionTitle, systemImage: "safari") { openRouter() }
                .buttonStyle(.borderedProminent)
                .disabled(network.routerURL == nil || network.routerAccess.status == .checking)
        }
        .padding(14)
        .background(
            theme.colors.surfaceElevated.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private var routerTarget: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DESTINATION")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(theme.colors.secondaryText)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("This Mac")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                    PrivacyProtectedText(
                        value: network.inspection.localIPv4 ?? "Not detected",
                        field: .networkIdentifier
                    )
                    .font(.title3.bold().monospaced())
                }
                Spacer()
                Button {
                    copy(network.inspection.localIPv4)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .disabled(network.inspection.localIPv4 == nil)
                .help("Copy this Mac's LAN address")
            }
            Text("Reserve this address in the router before forwarding ports.")
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            theme.colors.surfaceElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var portRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FORWARD TO THIS MAC")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(theme.colors.secondaryText)
            ForEach(network.portPlan.required) { requirement in
                HStack(spacing: 10) {
                    PrivacyProtectedText(
                        value: requirement.portLabel,
                        field: .networkPort
                    )
                    .font(.title3.bold().monospacedDigit())
                    .frame(width: 58, alignment: .leading)
                    Text(requirement.transport.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(theme.colors.accent)
                        .frame(width: 38, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(requirement.title).font(.caption.weight(.semibold))
                        Text(requirement.purpose).font(.caption2).foregroundStyle(theme.colors.secondaryText)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(
            theme.colors.surfaceElevated.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var clusterDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    "This `.25` node is using local thread workers, so worker traffic stays inside the master process. Do not open extra worker ranges for this Mac. If you later configure separate worker processes or machines, verify their active listeners before forwarding the documented worker ranges."
                )
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                ForEach(network.portPlan.clusterOnly) { requirement in
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(theme.colors.secondaryText)
                            .frame(width: 20)
                        Text(requirement.title).font(.caption.weight(.semibold))
                        Spacer()
                        PrivacyProtectedText(value: requirement.portLabel, field: .networkPort)
                            .font(.caption.monospacedDigit())
                        Text(requirement.transport.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.colors.secondaryText)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label("External worker ports", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Not required for local `.25` threads")
                    .font(.caption)
                    .foregroundStyle(theme.colors.success)
            }
        }
        .padding(16)
        .controlSurface()
    }

}
