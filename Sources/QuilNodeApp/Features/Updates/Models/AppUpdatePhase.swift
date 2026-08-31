import Foundation

/// Display state only. Sparkle owns the update transaction and recovery.
enum AppUpdatePhase: Equatable {
    case ready
    case checking
    case updateAvailable(version: String)
    case downloading
    case preparing
    case installing
    case current
    case unavailable(message: String)
    case failed(message: String)

    var title: String {
        switch self {
        case .ready: "Ready to check"
        case .checking: "Checking for QuilNode updates…"
        case .updateAvailable(let version): "QuilNode \(version) is available"
        case .downloading: "Downloading QuilNode"
        case .preparing: "Preparing the app update"
        case .installing: "Installing QuilNode"
        case .current: "QuilNode is up to date"
        case .unavailable: "No compatible update"
        case .failed: "App update interrupted"
        }
    }

    var detail: String {
        switch self {
        case .ready:
            "Application updates are separate from Quilibrium node updates."
        case .checking:
            "Reading the signed QuilNode release feed."
        case .updateAvailable:
            "Signed release metadata is available. The archive will be verified before extraction."
        case .downloading:
            "Downloading the app update. Sparkle shows transfer progress in its update window."
        case .preparing:
            "Verifying and preparing the downloaded application for installation."
        case .installing:
            "Replacing the QuilNode application. The node service runs independently."
        case .current:
            "No newer signed application release was found."
        case .unavailable(let message), .failed(let message):
            message
        }
    }
}
