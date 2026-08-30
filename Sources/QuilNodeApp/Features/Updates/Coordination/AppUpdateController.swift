import Foundation
import Sparkle

enum AppUpdatePhase: Equatable {
    case ready
    case checking
    case updateAvailable(version: String)
    case current
    case failed(message: String)

    var title: String {
        switch self {
        case .ready: "Ready to check"
        case .checking: "Checking for QuilNode updates…"
        case .updateAvailable(let version): "QuilNode \(version) is available"
        case .current: "QuilNode is up to date"
        case .failed: "Update check failed"
        }
    }

    var detail: String {
        switch self {
        case .ready:
            "Application updates are separate from Quilibrium node updates."
        case .checking:
            "Reading the signed QuilNode release feed."
        case .updateAvailable:
            "Sparkle verified the signed release metadata and will verify the archive before extraction."
        case .current:
            "No newer signed application release was found."
        case .failed(let message):
            message
        }
    }
}

/// App-lifetime owner for QuilNode's own update channel.
///
/// Node updates remain owned by `ReleaseChecker`; mixing the two lifecycles
/// would let dashboard navigation accidentally affect an application install.
/// Sparkle owns scheduling and installation while this controller contributes
/// observable state for the dashboard and settings surfaces.
@MainActor
final class AppUpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var phase: AppUpdatePhase = .ready

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    override init() {
        super.init()
        _ = controller
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var lastCheckedAt: Date? { controller.updater.lastUpdateCheckDate }
    var canCheck: Bool { controller.updater.canCheckForUpdates }
    var automaticallyChecks: Bool { controller.updater.automaticallyChecksForUpdates }

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        if enabled {
            controller.updater.resetUpdateCycleAfterShortDelay()
        }
        objectWillChange.send()
    }

    func checkNow() {
        phase = .checking
        controller.checkForUpdates(nil)
        objectWillChange.send()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        phase = .updateAvailable(version: item.displayVersionString)
        objectWillChange.send()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        phase = .current
        objectWillChange.send()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        phase = .failed(message: error.localizedDescription)
        objectWillChange.send()
    }
}
