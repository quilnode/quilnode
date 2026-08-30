import Foundation

extension NodeDiagnosticEvaluator {
    static func qclientCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard let ready = context.qclientReady, let compatible = context.qclientCompatible else {
            return check(
                id: "qclient", category: .tooling, state: .checking,
                title: "qclient", summary: "qclient provenance has not been inspected.",
                evidence: "The installation preflight has not completed.", repair: .refreshEvidence
            )
        }
        if ready && compatible {
            return check(
                id: "qclient", category: .tooling, state: .passed,
                title: "qclient", summary: "The local client is trusted and matches the node.",
                evidence: "Provenance and node compatibility passed."
            )
        }
        return check(
            id: "qclient", category: .tooling, state: .failed,
            title: "qclient",
            summary: ready ? "qclient does not match the installed node." : "A trusted qclient is not installed.",
            evidence: "Install the client matching the active node build.", repair: .repairQClient
        )
    }

    static func versionCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.initialRefreshComplete else {
            return check(
                id: "version", category: .tooling, state: .checking,
                title: "Node build identity", summary: "Reading the installed build identity.",
                evidence: "The first local probe has not completed."
            )
        }
        guard let version = context.snapshot.version, !version.isEmpty else {
            return check(
                id: "version", category: .tooling, state: .advisory,
                title: "Node build identity", summary: "The running version could not be identified.",
                evidence: "Refresh deep node information before updating.", repair: .refreshEvidence
            )
        }
        return check(
            id: "version", category: .tooling, state: .passed,
            title: "Node build identity", summary: "The running build reports version \(version).",
            evidence: "Version identity came from the local node."
        )
    }
}
