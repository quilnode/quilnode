import AppKit
import SwiftUI

extension NetworkReadinessView {
    var listenersHealthy: Bool {
        network.portPlan.required.allSatisfy { network.inspection.isListening(for: $0) }
    }

    var listenerValue: String {
        listenersHealthy
            ? network.portPlan.required.map(\.portLabel).joined(separator: " + ")
            : "Check ports"
    }

    var listenerDetail: String {
        if !listenersHealthy { return "One or more configured listeners are missing" }
        let transports = Set(network.portPlan.required.map(\.transport.rawValue)).sorted().joined(separator: " + ")
        return "\(transports) listeners verified on this process"
    }

    var inboundValue: String {
        if let count = monitor.snapshot.inboundConnectionsEstablished, count > 0 {
            return count.formatted()
        }
        if network.inspection.inboundPeerSockets > 0 {
            return network.inspection.inboundPeerSockets.formatted()
        }
        return network.inspection.inspectionSucceeded ? "None yet" : "Checking"
    }

    var inboundDetail: String {
        if (monitor.snapshot.inboundConnectionsEstablished ?? 0) > 0 {
            return "Established since node start"
        }
        if network.inspection.inboundPeerSockets > 0 {
            return "Live connections on a listening port"
        }
        return "No inbound connection recorded yet"
    }

    var hasInboundEvidence: Bool {
        (monitor.snapshot.inboundConnectionsEstablished ?? 0) > 0
            || network.inspection.inboundPeerSockets > 0
    }

    var firewallValue: String {
        if network.firewall.blockAllEnabled { return "Blocking all" }
        if !network.firewall.globalEnabled { return "Off" }
        switch network.firewall.nodeRule {
        case .allowed: return "Node allowed"
        case .blocked: return "Node blocked"
        case .missing: return "Rule missing"
        case .unavailable: return fallbackFirewallValue
        }
    }

    var firewallDetail: String {
        if network.firewall.isReady {
            return network.firewall.managedByQuilNode
                ? "Verified and maintained after updates"
                : "Explicit incoming rule verified"
        }
        if network.firewall.blockAllEnabled { return "Incoming node traffic is blocked" }
        if network.firewall.globalEnabled && network.firewall.nodeRule == .blocked {
            return "The current node is explicitly blocked"
        }
        if network.firewall.globalEnabled && network.firewall.nodeRule == .missing {
            return "Add an explicit rule for this node build"
        }
        return network.firewall.nodeRule == .unavailable
            ? "Secure service is verifying the rule"
            : "Host protection is available"
    }

    var firewallTint: Color {
        if network.firewall.isReady { return theme.colors.success }
        if network.firewall.blockAllEnabled || network.firewall.nodeRule == .blocked {
            return theme.colors.danger
        }
        return theme.colors.warning
    }

    var fallbackFirewallValue: String {
        switch network.inspection.firewallState {
        case .disabled: "Off"
        case .enabled: "On"
        case .blockingAll: "Blocking all"
        case .unknown: "Checking"
        }
    }

    var firewallStatusLabel: String {
        if network.firewall.isReady { return "Verified" }
        if network.firewall.blockAllEnabled { return "Review required" }
        if network.firewall.globalEnabled { return "Rule needed" }
        return network.firewall.nodeRule == .unavailable ? "Checking" : "Available"
    }

    var firewallGuideDetail: String {
        if network.firewall.nodeRule == .unavailable {
            return
                "The secure local service is upgrading or verifying the installed node rule. No firewall setting is changed while this check is unavailable."
        }
        if network.firewall.isReady {
            return
                "macOS Firewall is on and the installed node has an explicit incoming-connection rule. Router forwarding remains a separate manual boundary."
        }
        if network.firewall.blockAllEnabled {
            return
                "Block all incoming connections overrides application rules. Review this intentional macOS setting before expecting inbound peers."
        }
        if network.firewall.globalEnabled && network.firewall.nodeRule == .blocked {
            return
                "macOS Firewall is on, but this node build is blocked. QuilNode can safely repair only its own application rule."
        }
        if network.firewall.globalEnabled {
            return
                "macOS Firewall is on, but the current versioned node binary needs an explicit rule. QuilNode can add and maintain it."
        }
        return
            "Enable Apple’s built-in application firewall and add an explicit allow rule for the installed Quilibrium node—without changing other apps or router settings."
    }

    var firewallStatusSymbol: String {
        if network.firewall.isReady { return "checkmark.shield.fill" }
        if network.firewall.blockAllEnabled || network.firewall.nodeRule == .blocked {
            return "exclamationmark.shield.fill"
        }
        return "firewall.fill"
    }

    var firewallActionTitle: String {
        if network.isConfiguringFirewall { return "Applying…" }
        if network.firewall.nodeRule == .unavailable { return "Check again" }
        if network.firewall.blockAllEnabled { return "Review setting" }
        if network.firewall.isReady { return "Verify again" }
        if network.firewall.globalEnabled { return "Repair node access" }
        return "Secure this Mac"
    }

    var firewallActionSymbol: String {
        if network.firewall.nodeRule == .unavailable { return "arrow.clockwise" }
        if network.firewall.blockAllEnabled { return "gear" }
        if network.firewall.isReady { return "arrow.clockwise" }
        return "checkmark.shield"
    }

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

    var gatewayInterfaceLabel: String {
        if let name = network.gatewayRoute.interfaceDisplayName {
            return "via \(name)"
        }
        if let name = network.gatewayRoute.interfaceName {
            return "via \(name)"
        }
        return "from the macOS default route"
    }

    var gatewayStatusColor: Color {
        switch network.routerAccess.status {
        case .confirmed: theme.colors.success
        case .checking, .notChecked: theme.colors.info
        case .unconfirmed: theme.colors.warning
        case .unavailable: theme.colors.danger
        }
    }

    var gatewayStatusSymbol: String {
        switch network.routerAccess.status {
        case .confirmed: "checkmark.shield.fill"
        case .checking, .notChecked: "network"
        case .unconfirmed: "questionmark.circle.fill"
        case .unavailable: "exclamationmark.triangle.fill"
        }
    }

    var routerActionTitle: String {
        switch network.routerAccess.status {
        case .confirmed: "Open gateway page"
        case .unconfirmed: "Try gateway address"
        case .checking: "Checking…"
        case .notChecked: "Check gateway"
        case .unavailable: "Gateway unavailable"
        }
    }

    var statusColor: Color {
        switch network.assessment.state {
        case .inboundVerified: theme.colors.success
        case .waitingForEvidence, .inspecting: theme.colors.info
        case .reviewRouter: theme.colors.warning
        case .localConfigurationIssue, .offline: theme.colors.danger
        }
    }

    var statusSymbol: String {
        switch network.assessment.state {
        case .inboundVerified: "checkmark.seal.fill"
        case .waitingForEvidence, .inspecting: "antenna.radiowaves.left.and.right"
        case .reviewRouter: "wifi.exclamationmark"
        case .localConfigurationIssue: "exclamationmark.arrow.triangle.2.circlepath"
        case .offline: "power"
        }
    }

    func openRouter() {
        guard let url = network.routerURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openFirewallSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension?Firewall") else {
            return
        }
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
