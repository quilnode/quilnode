import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Centralizes the difference between an unobserved process, a detected
/// process whose telemetry is still arriving, and a complete live snapshot.
/// Views should never infer "offline" from the zero-filled bootstrap model.
struct NodeObservationPresentation {
    let phase: NodeObservationPhase
    let snapshot: NodeSnapshot

    var isCheckingProcess: Bool { phase == .checkingProcess }
    var isLoadingTelemetry: Bool { phase == .loadingTelemetry }
    var hasLiveTelemetry: Bool { phase.hasLiveTelemetry }

    var headerState: String {
        switch phase {
        case .checkingProcess: "Checking"
        case .loadingTelemetry: snapshot.isRunning ? "Detected" : "Stopped"
        case .ready: snapshot.isRunning ? "Live" : "Stopped"
        }
    }

    var headerScope: String {
        phase == .checkingProcess ? "Local node" : "Local"
    }

    var primaryTitle: String? {
        switch phase {
        case .checkingProcess: "Checking local node"
        case .loadingTelemetry: snapshot.isRunning ? "Node detected" : "Node offline"
        case .ready: nil
        }
    }

    var primaryDetail: String? {
        switch phase {
        case .checkingProcess:
            "Reading the managed launchd service. No node state has been assumed yet."
        case .loadingTelemetry where snapshot.isRunning:
            "The node process is running. Loading frames, peers, identity, allocations, and wallet telemetry locally."
        case .loadingTelemetry:
            "The managed service check confirmed that no node process is running."
        case .ready:
            nil
        }
    }

    var systemImage: String {
        switch phase {
        case .checkingProcess: "ellipsis.circle.fill"
        case .loadingTelemetry where snapshot.isRunning: "checkmark.circle.fill"
        case .loadingTelemetry: "stop.circle.fill"
        case .ready: snapshot.health.systemImage
        }
    }

    var accessibilityStatus: String {
        switch phase {
        case .checkingProcess: "Checking the local node process"
        case .loadingTelemetry where snapshot.isRunning: "Local node detected; loading live telemetry"
        case .loadingTelemetry: "Local node is stopped"
        case .ready: snapshot.health.label
        }
    }

    func value(_ liveValue: @autoclosure () -> String) -> String {
        hasLiveTelemetry ? liveValue() : "—"
    }

    func detail(_ liveDetail: @autoclosure () -> String) -> String {
        hasLiveTelemetry ? liveDetail() : "Reading local telemetry…"
    }
}

/// Stable, non-blocking placeholder for detail screens that require the first
/// complete telemetry sample. Navigation and the window remain responsive.
struct NodeObservationWaitingView: View {
    @Environment(\.quilTheme) private var theme
    let presentation: NodeObservationPresentation

    var body: some View {
        HStack(spacing: 15) {
            QuilLoadingIndicator(
                label: presentation.primaryTitle ?? "Loading local telemetry",
                detail: presentation.primaryDetail ?? "Reading the node's local telemetry sources."
            )
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlSurface(tint: theme.colors.info)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(presentation.accessibilityStatus)
    }
}
