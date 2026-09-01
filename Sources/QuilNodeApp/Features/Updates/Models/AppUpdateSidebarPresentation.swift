import Foundation

/// Small, deterministic view state for the persistent sidebar affordance.
/// Routine checks stay quiet; only a confirmed release or its active install
/// transaction earns space in the primary navigation.
struct AppUpdateSidebarPresentation: Equatable {
    enum Tone: Equatable {
        case available
        case progress
        case failure
    }

    let title: String
    let detail: String
    let systemImage: String
    let tone: Tone
    let showsProgress: Bool
    let isEnabled: Bool

    init?(phase: AppUpdatePhase, availableVersion: String?, canCheck: Bool) {
        switch phase {
        case .updateAvailable(let version):
            title = "App update"
            detail = version
            systemImage = "arrow.down.app.fill"
            tone = .available
            showsProgress = false
            isEnabled = canCheck
        case .downloading:
            title = "Downloading update"
            detail = availableVersion ?? "QuilNode"
            systemImage = "arrow.down.circle.fill"
            tone = .progress
            showsProgress = true
            isEnabled = canCheck
        case .preparing:
            title = "Verifying update"
            detail = availableVersion ?? "QuilNode"
            systemImage = "checkmark.shield.fill"
            tone = .progress
            showsProgress = true
            isEnabled = canCheck
        case .installing:
            title = "Installing update"
            detail = availableVersion ?? "QuilNode"
            systemImage = "shippingbox.fill"
            tone = .progress
            showsProgress = true
            isEnabled = canCheck
        case .failed where availableVersion != nil:
            title = "Update interrupted"
            detail = "Try again"
            systemImage = "exclamationmark.arrow.triangle.2.circlepath"
            tone = .failure
            showsProgress = false
            isEnabled = canCheck
        case .ready, .checking, .current, .unavailable, .failed:
            return nil
        }
    }
}
