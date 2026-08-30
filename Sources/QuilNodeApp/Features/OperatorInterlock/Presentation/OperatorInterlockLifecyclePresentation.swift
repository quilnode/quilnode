import Foundation

extension OperatorInterlockPresentation {
    static let startNode = OperatorInterlockModel(
        id: "start-node",
        eyebrow: "NODE LIFECYCLE",
        title: "Start node",
        outcome: "Load the managed service, reconnect locally, and verify fresh telemetry.",
        symbol: "play.circle.fill",
        tone: .success,
        steps: [
            .init(
                id: "load", title: "Load service", detail: "Start the managed process.", symbol: "play.fill",
                tone: .success),
            .init(
                id: "connect", title: "Reconnect", detail: "Open listeners and reconnect peers.", symbol: "network",
                tone: .information),
            .init(
                id: "verify", title: "Verify telemetry", detail: "Refresh process and frame evidence.",
                symbol: "waveform.path.ecg", tone: .success),
        ],
        changes: [
            .init(
                id: "process", title: "Node process", detail: "The managed node service starts running.",
                symbol: "power.circle.fill"),
            .init(
                id: "network", title: "Network participation", detail: "Configured listeners and peer sessions resume.",
                symbol: "network"),
        ],
        preserved: standardNodeBoundary,
        verification: ["Process running", "Listeners observed", "Fresh local telemetry"],
        trustNote: "The request goes only to QuilNode’s authenticated local service.",
        decisions: [
            .init(
                id: "start", title: "Start node", detail: "Resume local node participation.", actionTitle: "Start node",
                symbol: "play.fill", tone: .success, bullets: [])
        ],
        defaultDecisionID: "start",
        cancelTitle: "Cancel"
    )

    static let restartNode = OperatorInterlockModel(
        id: "restart-node",
        eyebrow: "NODE LIFECYCLE",
        title: "Restart node",
        outcome: "Pause the managed process briefly, resume it, and verify recovery automatically.",
        symbol: "arrow.clockwise.circle.fill",
        tone: .information,
        steps: [
            .init(
                id: "pause", title: "Pause service", detail: "Stop the managed process cleanly.", symbol: "pause.fill",
                tone: .information),
            .init(
                id: "resume", title: "Resume service", detail: "Load the same runtime and settings.",
                symbol: "play.fill", tone: .information),
            .init(
                id: "verify", title: "Verify telemetry", detail: "Refresh process, frame, and peer evidence.",
                symbol: "waveform.path.ecg", tone: .success),
        ],
        changes: [
            .init(
                id: "process", title: "Node process", detail: "The managed process stops briefly and starts again.",
                symbol: "arrow.clockwise"),
            .init(
                id: "connections", title: "Peer sessions", detail: "Live sessions reconnect after the service resumes.",
                symbol: "network"),
        ],
        preserved: standardNodeBoundary,
        verification: ["Process running", "Frame evidence refreshed", "Peer recovery observed"],
        trustNote: "This action is local. It does not alter your identity or submit a network transaction.",
        decisions: [
            .init(
                id: "restart", title: "Restart node", detail: "Briefly pause and resume the managed service.",
                actionTitle: "Restart node", symbol: "arrow.clockwise", tone: .information, bullets: [])
        ],
        defaultDecisionID: "restart",
        cancelTitle: "Cancel"
    )

    static let stopNode = OperatorInterlockModel(
        id: "stop-node",
        eyebrow: "NODE LIFECYCLE",
        title: "Stop node",
        outcome: "Unload the managed process and pause network participation until you start it again.",
        symbol: "stop.circle.fill",
        tone: .destructive,
        steps: [
            .init(
                id: "request", title: "Request stop", detail: "Ask the local service to unload the node.",
                symbol: "stop.fill", tone: .destructive),
            .init(
                id: "disconnect", title: "Close sessions", detail: "Listeners and peers stop with the process.",
                symbol: "network.slash", tone: .warning),
            .init(
                id: "confirm", title: "Confirm stopped", detail: "Refresh local process evidence.",
                symbol: "checkmark.circle.fill", tone: .success),
        ],
        changes: [
            .init(
                id: "process", title: "Node process", detail: "The managed service is unloaded.", symbol: "power.circle"
            ),
            .init(
                id: "participation", title: "Network participation",
                detail: "Proving and peer sessions pause while stopped.", symbol: "pause.circle.fill"),
        ],
        preserved: standardNodeBoundary,
        verification: ["Process stopped", "Listeners closed", "Local data retained"],
        trustNote: "Stopping does not delete stores or retire the node identity; it only pauses the service.",
        decisions: [
            .init(
                id: "stop", title: "Stop node", detail: "Pause the managed service until manually restarted.",
                actionTitle: "Stop node", symbol: "stop.fill", tone: .destructive, bullets: [])
        ],
        defaultDecisionID: "stop",
        cancelTitle: "Cancel"
    )

    static let standardNodeBoundary: [OperatorInterlockScopeItem] = [
        .init(
            id: "identity", title: "Identity and keys",
            detail: "The active keyset and every private key byte remain untouched.", symbol: "person.badge.key.fill"),
        .init(
            id: "stores", title: "Stores",
            detail: "Frame, clock, hypergraph, and proving stores are not deleted or replaced.",
            symbol: "externaldrive.fill"),
        .init(
            id: "configuration", title: "Configuration",
            detail: "Node settings, ports, peers, and app preferences remain unchanged.", symbol: "gearshape.fill"),
        .init(
            id: "binary", title: "Node binary", detail: "The installed runtime and version are not replaced.",
            symbol: "shippingbox.fill"),
    ]
}
