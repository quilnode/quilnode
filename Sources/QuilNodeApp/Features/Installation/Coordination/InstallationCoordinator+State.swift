import Foundation

@MainActor
extension InstallationCoordinator {
    var requiresFirstInstall: Bool {
        guard let preflight else { return false }
        return !preflight.nodeInstalled
    }

    var requiresPlatformAuthorization: Bool {
        guard let preflight else { return false }
        return preflight.nodeInstalled && !preflight.secureServiceReady
    }

    var requiresQClientSetup: Bool {
        guard let preflight else { return false }
        return preflight.nodeInstalled && preflight.secureServiceReady
            && (preflight.qclientStatus?.isReady != true || !preflight.qclientCompatibleWithNode)
    }

    var isWorking: Bool {
        [.inspecting, .downloading, .verifying, .authorizing, .installing, .validating].contains(phase)
    }

    var canPrepareSignedInstallation: Bool {
        preflight?.productionReady == true && identityPlan != nil && !isWorking
    }
}
