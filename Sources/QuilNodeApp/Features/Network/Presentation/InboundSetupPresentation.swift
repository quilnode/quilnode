import Foundation

/// The operator's inbound journey. These are workflow steps, not inferred
/// protocol states: a router remains manual until the node observes traffic.
enum InboundSetupStep: String, CaseIterable, Identifiable, Hashable {
    case listenerProfile
    case firewall
    case router
    case inboundProof

    var id: String { rawValue }

    var ordinal: Int {
        (Self.allCases.firstIndex(of: self) ?? 0) + 1
    }

    var title: String {
        switch self {
        case .listenerProfile: "Listener profile"
        case .firewall: "macOS firewall"
        case .router: "Router forwarding"
        case .inboundProof: "Inbound proof"
        }
    }

    var shortDetail: String {
        switch self {
        case .listenerProfile: "Configure ports"
        case .firewall: "Allow node binary"
        case .router: "Manual on router"
        case .inboundProof: "Await traffic"
        }
    }

    var symbol: String {
        switch self {
        case .listenerProfile: "dot.radiowaves.left.and.right"
        case .firewall: "checkmark.shield"
        case .router: "wifi.router"
        case .inboundProof: "scope"
        }
    }
}

enum InboundSetupEvidenceState: Equatable {
    case verified
    case needsAction
    case manual
    case waiting

    var label: String {
        switch self {
        case .verified: "Verified"
        case .needsAction: "Needs action"
        case .manual: "Manual"
        case .waiting: "Waiting"
        }
    }
}

struct InboundSetupStepPresentation: Identifiable, Equatable {
    let step: InboundSetupStep
    let state: InboundSetupEvidenceState

    var id: InboundSetupStep { step }
}

enum InboundSetupPresentation {
    static func steps(from workspace: NetworkWorkspacePresentation) -> [InboundSetupStepPresentation] {
        let listeners = workspace.stage(.listeners)
        return [
            InboundSetupStepPresentation(
                step: .listenerProfile,
                state: listeners.state == .verified ? .verified : .needsAction
            ),
            InboundSetupStepPresentation(
                step: .firewall,
                state: workspace.firewall.isReady ? .verified : .needsAction
            ),
            InboundSetupStepPresentation(
                step: .router,
                state: workspace.inboundEvidence ? .verified : .manual
            ),
            InboundSetupStepPresentation(
                step: .inboundProof,
                state: workspace.inboundEvidence ? .verified : .waiting
            ),
        ]
    }

    static func recommendedEntryStep(from workspace: NetworkWorkspacePresentation) -> InboundSetupStep {
        for item in steps(from: workspace) {
            switch item.state {
            case .verified:
                continue
            case .needsAction, .manual, .waiting:
                return item.step
            }
        }
        return .inboundProof
    }
}
