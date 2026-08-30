import Foundation

extension OperatorInterlockPresentation {
    static let firewallRepair = OperatorInterlockModel(
        id: "diagnostic-firewall",
        eyebrow: "DIAGNOSTIC REPAIR",
        title: "Configure macOS Firewall",
        outcome: "Apply the minimum local rule for the installed node, then verify the effective firewall state.",
        symbol: "firewall.fill",
        tone: .information,
        steps: [
            .init(
                id: "inspect", title: "Inspect rule", detail: "Read the current local firewall state.",
                symbol: "doc.text.magnifyingglass", tone: .information),
            .init(
                id: "apply", title: "Apply minimum", detail: "Allow only the installed node executable.",
                symbol: "checkmark.shield.fill", tone: .information),
            .init(
                id: "verify", title: "Verify result", detail: "Confirm firewall and executable status.",
                symbol: "checkmark.circle.fill", tone: .success),
        ],
        changes: [
            .init(
                id: "binary-rule", title: "Installed node rule",
                detail: "The current managed node executable is added or unblocked.", symbol: "app.badge.checkmark"),
            .init(
                id: "block-all", title: "Block-all mode",
                detail: "Disabled only if it prevents the explicit node rule from working.", symbol: "switch.2"),
        ],
        preserved: standardNodeBoundary + [
            .init(
                id: "router", title: "Router configuration",
                detail: "No gateway page, NAT rule, or port mapping is changed.", symbol: "wifi.router.fill")
        ],
        verification: ["Firewall remains enabled", "Node executable allowed", "Router untouched"],
        trustNote: "macOS may request administrator approval. QuilNode never receives or stores the password.",
        decisions: [
            .init(
                id: "configure", title: "Configure firewall", detail: "Apply and verify the minimum local rule.",
                actionTitle: "Configure firewall", symbol: "firewall.fill", tone: .information, bullets: [])
        ],
        defaultDecisionID: "configure",
        cancelTitle: "Cancel"
    )
}
