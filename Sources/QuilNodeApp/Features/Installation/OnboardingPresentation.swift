import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum OnboardingStage: Int, CaseIterable, Identifiable {
    case host
    case runtime
    case identity
    case network

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .host: "This Mac"
        case .runtime: "Runtime"
        case .identity: "Identity"
        case .network: "Network"
        }
    }

    var systemImage: String {
        switch self {
        case .host: "desktopcomputer"
        case .runtime: "gearshape.2.fill"
        case .identity: "lock.shield.fill"
        case .network: "globe"
        }
    }

    func status(relativeTo current: OnboardingStage) -> String {
        if rawValue < current.rawValue {
            switch self {
            case .host: "Ready"
            case .runtime: "Installed"
            case .identity: "Protected"
            case .network: "Configured"
            }
        } else if self == current {
            "Current step"
        } else {
            "Coming next"
        }
    }

    static func current(for phase: FirstInstallPhase) -> OnboardingStage {
        switch phase {
        case .inspecting, .ready, .failed:
            .host
        case .downloading, .verifying, .awaitingAuthorization, .authorizing, .installing, .validating, .complete:
            .runtime
        }
    }
}

enum IdentityOnboardingChoice: String, CaseIterable, Identifiable {
    case keep
    case importKeyset
    case create

    var id: String { rawValue }

    static func initialChoice(hasActiveIdentity: Bool) -> IdentityOnboardingChoice? {
        hasActiveIdentity ? .keep : nil
    }

    var title: String {
        switch self {
        case .keep: "Keep detected identity"
        case .importKeyset: "Import an existing keyset"
        case .create: "Create a new identity"
        }
    }

    var detail: String {
        switch self {
        case .keep: "Protect the identity already active on this Mac."
        case .importKeyset: "Select a legacy or current keyset for local validation."
        case .create: "Generate a current identity with the verified local client."
        }
    }

    var systemImage: String {
        switch self {
        case .keep: "checkmark.shield.fill"
        case .importKeyset: "square.and.arrow.down.fill"
        case .create: "plus.circle.fill"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .keep: "Protect & continue"
        case .importKeyset: "Choose keyset…"
        case .create: "Create & continue"
        }
    }
}

struct OnboardingRuntimeProgress: Equatable {
    let step: Int
    let total: Int
    let title: String

    static func firstInstall(phase: FirstInstallPhase) -> Self {
        switch phase {
        case .inspecting, .ready, .failed:
            .init(step: 1, total: 6, title: "Inspect this Mac")
        case .downloading:
            .init(step: 2, total: 6, title: "Acquire signed artifacts")
        case .verifying:
            .init(step: 3, total: 6, title: "Verify release trust")
        case .awaitingAuthorization, .authorizing:
            .init(step: 4, total: 6, title: "Authorize local service")
        case .installing:
            .init(step: 5, total: 6, title: "Install restricted runtime")
        case .validating, .complete:
            .init(step: 6, total: 6, title: "Validate local health")
        }
    }

    static func qclient(phase: FirstInstallPhase) -> Self {
        switch phase {
        case .inspecting, .ready, .failed:
            .init(step: 1, total: 4, title: "Resolve matching client")
        case .downloading:
            .init(step: 2, total: 4, title: "Acquire client artifact")
        case .verifying, .awaitingAuthorization, .authorizing:
            .init(step: 3, total: 4, title: "Verify provenance")
        case .installing, .validating, .complete:
            .init(step: 4, total: 4, title: "Install & re-check")
        }
    }
}
