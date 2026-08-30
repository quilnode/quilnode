import Foundation

enum UpdateFlightStage: String, CaseIterable, Identifiable, Sendable {
    case discover
    case verify
    case acquire
    case stage
    case activate
    case health
    case rollback

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: "Discover"
        case .verify: "Verify"
        case .acquire: "Acquire / Build"
        case .stage: "Stage"
        case .activate: "Activate"
        case .health: "Health gate"
        case .rollback: "Rollback guard"
        }
    }

    var detail: String {
        switch self {
        case .discover: "Pin candidate"
        case .verify: "Prove trust"
        case .acquire: "Fetch or compile"
        case .stage: "Seal immutable plan"
        case .activate: "Brief runtime switch"
        case .health: "Validate local node"
        case .rollback: "Restore on failure"
        }
    }

    var systemImage: String {
        switch self {
        case .discover: "scope"
        case .verify: "checkmark.seal"
        case .acquire: "shippingbox"
        case .stage: "square.stack.3d.up"
        case .activate: "arrow.triangle.swap"
        case .health: "waveform.path.ecg"
        case .rollback: "arrow.uturn.backward.circle"
        }
    }

    var section: NodeUpdatePlanSection {
        switch self {
        case .activate, .health, .rollback: .activation
        default: .preparation
        }
    }

    static func current(for step: NodeUpdateStep) -> Self {
        switch step {
        case .selectCandidate: .discover
        case .verifyTrust: .verify
        case .acquire, .compileNode, .linkNode: .acquire
        case .inspectArtifact, .client, .sealPlan: .stage
        case .switchRuntime: .activate
        case .healthGate: .health
        }
    }
}
