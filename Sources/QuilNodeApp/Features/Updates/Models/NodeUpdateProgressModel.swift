import Foundation

/// The user-facing update plan is deliberately independent from log copy.
/// ReleaseChecker reports human-readable phases, but navigation, progress, and
/// accessibility must remain stable when that copy changes.
enum NodeUpdatePlanSection: String, Sendable {
    case preparation
    case activation

    var title: String {
        switch self {
        case .preparation: "Prepare safely"
        case .activation: "Switch and prove"
        }
    }

    var detail: String {
        switch self {
        case .preparation: "The current node keeps running while the candidate is acquired, built, and verified."
        case .activation:
            "A rollback point is secured, then the node briefly restarts and must pass local health checks."
        }
    }
}

enum NodeUpdateServiceImpact: Equatable, Sendable {
    case online
    case briefRestart
    case unaffected

    var title: String {
        switch self {
        case .online: "Node stays online"
        case .briefRestart: "Brief restart window"
        case .unaffected: "Node is not restarted"
        }
    }

    var systemImage: String {
        switch self {
        case .online: "bolt.horizontal.circle.fill"
        case .briefRestart: "arrow.clockwise.circle.fill"
        case .unaffected: "checkmark.circle.fill"
        }
    }
}

enum NodeUpdateWorkflow: String, Sendable {
    case signedNode
    case sourceNode
    case qclient
    case generic

    var steps: [NodeUpdateStep] {
        switch self {
        case .signedNode:
            [.selectCandidate, .acquire, .verifyTrust, .inspectArtifact, .sealPlan, .switchRuntime, .healthGate]
        case .sourceNode, .generic:
            [
                .selectCandidate, .acquire, .verifyTrust, .compileNode, .linkNode,
                .inspectArtifact, .client, .sealPlan, .switchRuntime, .healthGate,
            ]
        case .qclient:
            [.selectCandidate, .acquire, .verifyTrust, .inspectArtifact, .sealPlan, .switchRuntime]
        }
    }

    var serviceImpactDuringActivation: NodeUpdateServiceImpact {
        self == .qclient ? .unaffected : .briefRestart
    }

    func defaultDuration(for step: NodeUpdateStep) -> TimeInterval {
        switch (self, step) {
        case (_, .selectCandidate): 10
        case (.signedNode, .acquire), (.qclient, .acquire): 90
        case (.sourceNode, .acquire), (.generic, .acquire): 35
        case (_, .verifyTrust): 90
        case (_, .compileNode): 5 * 60
        case (_, .linkNode): 6 * 60
        case (_, .inspectArtifact): 20
        case (_, .client): 20
        case (_, .sealPlan): 20
        case (.qclient, .switchRuntime): 20
        case (_, .switchRuntime): 20
        case (_, .healthGate): 90
        }
    }
}

enum NodeUpdateStep: String, CaseIterable, Identifiable, Sendable {
    case selectCandidate
    case acquire
    case verifyTrust
    case compileNode
    case linkNode
    case inspectArtifact
    case client
    case sealPlan
    case switchRuntime
    case healthGate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selectCandidate: "Pin candidate"
        case .acquire: "Acquire"
        case .verifyTrust: "Verify trust"
        case .compileNode: "Compile"
        case .linkNode: "Link"
        case .inspectArtifact: "Inspect binary"
        case .client: "Match qclient"
        case .sealPlan: "Seal plan"
        case .switchRuntime: "Switch runtime"
        case .healthGate: "Health gate"
        }
    }

    var shortTitle: String {
        switch self {
        case .selectCandidate: "Pin"
        case .verifyTrust: "Trust"
        case .inspectArtifact: "Inspect"
        case .sealPlan: "Seal"
        case .switchRuntime: "Switch"
        case .healthGate: "Health"
        default: title
        }
    }

    var systemImage: String {
        switch self {
        case .selectCandidate: "scope"
        case .acquire: "arrow.down.circle"
        case .verifyTrust: "checkmark.seal"
        case .compileNode: "hammer"
        case .linkNode: "link"
        case .inspectArtifact: "doc.text.magnifyingglass"
        case .client: "terminal"
        case .sealPlan: "shippingbox"
        case .switchRuntime: "arrow.triangle.swap"
        case .healthGate: "waveform.path.ecg"
        }
    }

    var section: NodeUpdatePlanSection {
        switch self {
        case .switchRuntime, .healthGate: .activation
        default: .preparation
        }
    }

    func impact(in workflow: NodeUpdateWorkflow) -> NodeUpdateServiceImpact {
        section == .preparation ? .online : workflow.serviceImpactDuringActivation
    }

    /// Compatibility mapping for low-level workers that still report a phase
    /// string. New orchestration code should set `step` directly.
    static func classify(phase: String, workflow: NodeUpdateWorkflow) -> Self {
        let value = phase.lowercased()
        if value.contains("update complete") || value.contains("health gate")
            || value.contains("health-check passed") || value.contains("validating local node")
        {
            return workflow == .qclient ? .switchRuntime : .healthGate
        }
        if value.contains("activat") || value.contains("ready to install")
            || value.contains("installing signed node") || value.contains("node installed")
        {
            return .switchRuntime
        }
        if value.contains("integrity metadata") || value.contains("staging")
            || value.contains("sealing installation") || value.contains("verified and ready")
        {
            return .sealPlan
        }
        if value.contains("qclient") || value.contains("client") { return .client }
        if value.contains("checking built") || value.contains("checking downloaded")
            || value.contains("validating staged") || value.contains("matching qclient verified")
        {
            return .inspectArtifact
        }
        if value.contains("linking optimized") { return .linkNode }
        if value.contains("compiling node") { return .compileNode }
        if value.contains("seniority") || value.contains("verifying signed")
            || value.contains("verifying official") || value.contains("release trust")
        {
            return .verifyTrust
        }
        if value.contains("download") || value.contains("clone") || value.contains("fetch")
            || value.contains("checkout") || value.contains("build cache")
        {
            return .acquire
        }
        if workflow == .signedNode || workflow == .qclient, value.contains("verif") {
            return .verifyTrust
        }
        return .selectCandidate
    }
}

extension NodeUpdateProgress {
    var orderedSteps: [NodeUpdateStep] { workflow.steps }

    var currentStepNumber: Int {
        (orderedSteps.firstIndex(of: step) ?? 0) + 1
    }

    var currentImpact: NodeUpdateServiceImpact { step.impact(in: workflow) }

    var completedStepCount: Int {
        if status == .succeeded { return orderedSteps.count }
        return max(currentStepNumber - 1, 0)
    }

    /// The displayed percentage is an estimate of elapsed work-time, not a
    /// Cargo package count. Completed stages contribute their learned/default
    /// duration; the active stage advances against its predicted duration and
    /// intentionally caps at 95% until the stage actually completes.
    func timeWeightedFraction(at now: Date = Date()) -> Double {
        if status == .succeeded { return 1 }
        let steps = orderedSteps
        guard let index = steps.firstIndex(of: step) else { return boundedFraction }
        let durations = steps.map { workflow.defaultDuration(for: $0) }
        let completed = durations.prefix(index).reduce(0, +)
        let stageElapsed = max(now.timeIntervalSince(stepStartedAt), 0)
        let predicted = max(expectedPhaseDuration ?? durations[index], stageElapsed * 1.12, 1)
        let active = predicted * min(stageElapsed / predicted, 0.95)
        let adjustedTotal = durations.reduce(0, +) - durations[index] + predicted
        return min(max((completed + active) / max(adjustedTotal, 1), 0.01), 0.99)
    }

    func workflowRemainingRange(at now: Date = Date()) -> ClosedRange<TimeInterval>? {
        guard status == .running, step != .switchRuntime || phase != "Ready to install" else { return nil }
        let steps = orderedSteps
        guard let index = steps.firstIndex(of: step) else { return nil }
        let stageElapsed = max(now.timeIntervalSince(stepStartedAt), 0)
        let baseline = workflow.defaultDuration(for: step)
        let predicted = max(expectedPhaseDuration ?? baseline, stageElapsed * 1.12)
        let currentRemaining = max(predicted - stageElapsed, 3)
        let later = steps.dropFirst(index + 1).reduce(0) {
            $0 + workflow.defaultDuration(for: $1)
        }
        let estimate = min(currentRemaining + later, 3 * 60 * 60)
        let uncertainty = max(estimate * (workflow == .sourceNode ? 0.28 : 0.18), 20)
        return max(estimate - uncertainty, 1)...min(estimate + uncertainty, 3 * 60 * 60)
    }
}
