import AppKit

extension NetworkReadinessView {
    func performFirewallAction() {
        if network.firewall.nodeRule == .unavailable {
            Task { await network.refresh() }
        } else if network.firewall.blockAllEnabled {
            openFirewallSettings()
        } else if network.firewall.isReady {
            Task { await network.refresh() }
        } else {
            showingFirewallConfirmation = true
        }
    }

    func openRouter() {
        guard let url = network.routerURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openFirewallSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall")
        else { return }
        NSWorkspace.shared.open(url)
    }

    func copyPlan() {
        let target = network.inspection.localIPv4 ?? "THIS_MAC_LAN_IP"
        let gateway = network.gatewayRoute.address ?? "USE_ROUTER_APP_OR_DOCUMENTATION"
        let rules = network.portPlan.required.map {
            "\($0.portLabel) \($0.transport.rawValue) → \(target), same internal and external port"
        }.joined(separator: "\n")
        copy(
            "QuilNode verified router plan (\(network.activePortProfile.title))\nDefault gateway detected by macOS: \(gateway)\nReserve \(target) with DHCP\n\(rules)\nDo not enable DMZ or broad port ranges. Use the router manufacturer app if the gateway has no web interface."
        )
    }

    func copy(_ value: String?) {
        guard let value else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
