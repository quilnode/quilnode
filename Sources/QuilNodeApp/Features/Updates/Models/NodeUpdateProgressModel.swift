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
                .selectCandidate, .acquire, .verifyTrust, .resolveDependencies,
                .compileNode, .linkNode,
                .inspectArtifact, .client, .sealPlan, .switchRuntime, .healthGate,
            ]
        case .qclient:
            [.selectCandidate, .acquire, .verifyTrust, .inspectArtifact, .sealPlan, .switchRuntime]
        }
    }

    var serviceImpactDuringActivation: NodeUpdateServiceImpact {
        self == .qclient ? .unaffected : .briefRestart
    }

    func permitsTransition(from current: NodeUpdateStep, to next: NodeUpdateStep) -> Bool {
        guard let currentIndex = steps.firstIndex(of: current),
            let nextIndex = steps.firstIndex(of: next)
        else { return false }
        return nextIndex >= currentIndex
    }
}

enum NodeUpdateStep: String, CaseIterable, Codable, Identifiable, Sendable {
    case selectCandidate
    case acquire
    case verifyTrust
    case resolveDependencies
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
        case .resolveDependencies: "Dependencies"
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
        case .resolveDependencies: "Dependencies"
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
        case .resolveDependencies: "shippingbox.and.arrow.backward"
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
        if value.contains("resolving locked") || value.contains("dependencies") {
            return .resolveDependencies
        }
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

}
