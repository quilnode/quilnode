import Foundation

extension NodeDiagnosticEvaluator {
    static func serviceCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        switch context.serviceAvailable {
        case nil:
            return check(
                id: "operator-service", category: .runtime, state: .checking,
                title: "Operator service", summary: "Checking the authorized local service.",
                evidence: "No service result has been collected yet.", repair: .refreshEvidence
            )
        case true:
            return check(
                id: "operator-service", category: .runtime, state: .passed,
                title: "Operator service", summary: "Authorized lifecycle operations are available.",
                evidence: "The code-signature-pinned local service answered successfully."
            )
        case false:
            return check(
                id: "operator-service", category: .runtime, state: .failed,
                title: "Operator service", summary: "Lifecycle operations are unavailable.",
                evidence: "The local service did not pass its availability check.", repair: .openUpdates
            )
        }
    }

    static func processCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.initialRefreshComplete else {
            return check(
                id: "process", category: .runtime, state: .checking,
                title: "Node process", summary: "Looking for the local node process.",
                evidence: "The first process probe has not completed.", repair: .refreshEvidence
            )
        }
        if context.snapshot.isRunning {
            return check(
                id: "process", category: .runtime, state: .passed,
                title: "Node process", summary: "The node process is alive.",
                evidence: context.snapshot.processID.map { "Local process ID \($0) is present." }
                    ?? "Process evidence is present.",
                observedAt: context.snapshot.collectedAt
            )
        }
        return check(
            id: "process", category: .runtime, state: .failed,
            title: "Node process", summary: "The node process is not running.",
            evidence: "A completed local process probe found no active node.",
            observedAt: context.snapshot.collectedAt, repair: .startNode
        )
    }

    static func telemetryCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.initialRefreshComplete else {
            return check(
                id: "telemetry", category: .runtime, state: .checking,
                title: "Local telemetry", summary: "Waiting for local evidence.",
                evidence: "Metrics and log freshness have not been evaluated.", repair: .refreshEvidence
            )
        }
        guard context.snapshot.isRunning else {
            return check(
                id: "telemetry", category: .runtime, state: .checking,
                title: "Local telemetry", summary: "Telemetry is unavailable while the node is stopped.",
                evidence: "Start the node before evaluating telemetry."
            )
        }
        let dates = [context.snapshot.metricsUpdatedAt, context.snapshot.logLastModifiedAt].compactMap { $0 }
        guard let newest = dates.max() else {
            return check(
                id: "telemetry", category: .runtime, state: .advisory,
                title: "Local telemetry",
                summary: "The process is alive, but no fresh metric or log timestamp is available.",
                evidence: "This can occur briefly during startup.", repair: .refreshEvidence
            )
        }
        let age = max(context.now.timeIntervalSince(newest), 0)
        let state: NodeDiagnosticState = age < 90 ? .passed : (age < 300 ? .advisory : .failed)
        return check(
            id: "telemetry", category: .runtime, state: state,
            title: "Local telemetry",
            summary: state == .passed ? "Local evidence is fresh." : "Local evidence is \(ageDescription(age)) old.",
            evidence: "Newest local metric or log observation: \(newest.formatted(date: .omitted, time: .standard)).",
            observedAt: newest, repair: state == .passed ? nil : .refreshEvidence
        )
    }
}
