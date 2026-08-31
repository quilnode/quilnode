import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

/// Converts durable service stages into stable onboarding copy and progress.
/// The service owns facts; the interface owns presentation.
enum InstallationOperationPresentation {
    static func progress(
        for update: PrivilegedServiceClient.OperationProgress,
        workflow: NodeUpdateWorkflow,
        startedAt: Date
    ) -> NodeUpdateProgress {
        let stage = update.stage ?? .accepted
        return NodeUpdateProgress(
            workflow: workflow,
            step: step(for: stage, message: update.message, workflow: workflow),
            phase: title(for: stage),
            detail: update.message,
            fraction: fraction(for: stage, workflow: workflow),
            startedAt: startedAt,
            isEstimate: false
        )
    }

    static func elapsedDescription(from startedAt: Date, to now: Date) -> String {
        let seconds = max(Int(now.timeIntervalSince(startedAt)), 0)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "Elapsed \(minutes)m \(remainder)s" : "Elapsed \(remainder)s"
    }

    private static func title(for stage: PrivilegedOperationStage) -> String {
        switch stage {
        case .accepted: "Installer accepted"
        case .waitingForExclusiveAccess: "Waiting for installer access"
        case .validatingPlan: "Validating sealed plan"
        case .verifyingArtifact: "Verifying staged artifact"
        case .installingFiles: "Installing verified files"
        case .verifyingInstalledArtifact: "Verifying installed copy"
        case .probingRuntime: "Checking runtime version"
        case .recordingProvenance: "Recording provenance"
        case .activatingRuntime: "Starting node runtime"
        case .validatingHealth: "Validating local health"
        case .completed: "Installation complete"
        }
    }

    private static func fraction(
        for stage: PrivilegedOperationStage,
        workflow: NodeUpdateWorkflow
    ) -> Double {
        let qclientFraction: [PrivilegedOperationStage: Double] = [
            .accepted: 0.90,
            .waitingForExclusiveAccess: 0.91,
            .validatingPlan: 0.92,
            .verifyingArtifact: 0.94,
            .installingFiles: 0.96,
            .verifyingInstalledArtifact: 0.97,
            .probingRuntime: 0.98,
            .recordingProvenance: 0.99,
            .completed: 1,
        ]
        let nodeFraction: [PrivilegedOperationStage: Double] = [
            .accepted: 0.76,
            .waitingForExclusiveAccess: 0.77,
            .validatingPlan: 0.78,
            .verifyingArtifact: 0.80,
            .installingFiles: 0.86,
            .verifyingInstalledArtifact: 0.88,
            .probingRuntime: 0.90,
            .recordingProvenance: 0.91,
            .activatingRuntime: 0.94,
            .validatingHealth: 0.97,
            .completed: 1,
        ]
        return (workflow == .qclient ? qclientFraction[stage] : nodeFraction[stage]) ?? 0.90
    }

    private static func step(
        for stage: PrivilegedOperationStage,
        message: String,
        workflow: NodeUpdateWorkflow
    ) -> NodeUpdateStep {
        if workflow == .qclient { return .switchRuntime }
        switch stage {
        case .accepted, .waitingForExclusiveAccess, .validatingPlan:
            return .sealPlan
        case .verifyingArtifact, .verifyingInstalledArtifact, .probingRuntime, .recordingProvenance:
            return message.localizedCaseInsensitiveContains("qclient") ? .client : .inspectArtifact
        case .installingFiles, .activatingRuntime:
            return .switchRuntime
        case .validatingHealth, .completed:
            return .healthGate
        }
    }
}
