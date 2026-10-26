import Foundation

@MainActor
extension InstallationCoordinator {
    func markFailure(_ detail: String) {
        phase = .failed
        error = detail
        if var current = progress {
            current.status = .failed
            current.updatedAt = Date()
            progress = current
        }
    }

    var requiresFirstInstall: Bool {
        guard let preflight else { return false }
        return !preflight.nodeInstalled
    }

    var requiresPlatformAuthorization: Bool {
        guard let preflight else { return false }
        // A read timeout is not evidence of an old helper. Keep Diagnostics
        // usable instead of reopening administrator onboarding mid-session.
        // The live readiness stays false and every operation still checks it.
        if preflight.secureServiceBuild == nil && hasVerifiedServiceThisRun { return false }
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
