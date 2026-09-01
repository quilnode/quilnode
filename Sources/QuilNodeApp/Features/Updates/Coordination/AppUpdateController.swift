import Combine
import Foundation
import Sparkle

/// App-lifetime Sparkle owner. It has no dependency on node lifecycle or custody.
/// Injecting a disposable bundle and user driver permits real updater tests
/// without targeting the installed app or opening production update windows.
@MainActor
final class AppUpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var phase: AppUpdatePhase = .ready
    @Published private(set) var canCheck = false
    @Published private(set) var lastAttemptAt: Date?
    @Published private(set) var availableVersion: String?

    private let bundle: Bundle
    private let userDriver: any SPUUserDriver
    private var observations: Set<AnyCancellable> = []
    private var started = false
    private lazy var updater = SPUUpdater(
        hostBundle: bundle, applicationBundle: bundle, userDriver: userDriver, delegate: self
    )

    init(bundle: Bundle = .main, userDriver: (any SPUUserDriver)? = nil, startingUpdater: Bool = true) {
        self.bundle = bundle
        self.userDriver = userDriver ?? SPUStandardUserDriver(hostBundle: bundle, delegate: nil)
        super.init()
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheck = $0 }
            .store(in: &observations)
        updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.lastAttemptAt = $0 }
            .store(in: &observations)
        if startingUpdater { start() }
    }

    var currentVersion: String { AppVersion(info: bundle.infoDictionary ?? [:]).displayVersion }
    var currentBuild: String { AppVersion(info: bundle.infoDictionary ?? [:]).build }
    var automaticallyChecks: Bool { updater.automaticallyChecksForUpdates }

    func start() {
        guard !started else { return }
        do {
            try updater.start()
            started = true
            // Sparkle explicitly permits one forced background check in the
            // same run-loop turn as startup. This makes a newly published
            // release discoverable on launch without coupling checks to window
            // creation or disturbing Sparkle's long-lived scheduler.
            if updater.automaticallyChecksForUpdates {
                updater.checkForUpdatesInBackground()
            }
        } catch {
            apply(error)
        }
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        updater.automaticallyChecksForUpdates = enabled
        // Sparkle persists this preference and resets its own schedule after
        // the setting changes; a second reset here would be redundant.
        objectWillChange.send()
    }

    func checkNow() {
        guard started, updater.canCheckForUpdates else { return }
        // During an existing session Sparkle focuses its window. Do not replace
        // download/install progress with a misleading new "checking" state.
        if !updater.sessionInProgress, availableVersion == nil { phase = .checking }
        updater.checkForUpdates()
    }

    /// Opens or focuses Sparkle's trusted update flow for a release already
    /// discovered by the signed-feed scheduler. Sparkle remains responsible
    /// for release notes, archive verification, installation, and relaunch.
    func installAvailableUpdate() {
        guard availableVersion != nil else {
            checkNow()
            return
        }
        guard started, updater.canCheckForUpdates else { return }
        updater.checkForUpdates()
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        phase = .checking
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        availableVersion = item.displayVersionString
        phase = .updateAvailable(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        availableVersion = nil
        apply(error)
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        phase = .downloading
    }

    func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
        phase = .preparing
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        phase = .installing
    }

    func userDidCancelDownload(_ updater: SPUUpdater) {
        restoreAvailableUpdate()
    }

    func updater(
        _ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
        forUpdate item: SUAppcastItem, state: SPUUserUpdateState
    ) {
        if choice == .skip {
            availableVersion = nil
            phase = .ready
        }
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
        apply(error)
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if let error {
            apply(error)
        } else if phase == .checking {
            // A dismissed/cancelled check is not evidence that the app is current.
            phase = .ready
        }
    }

    private func apply(_ error: any Error) {
        switch AppUpdateOutcome.classify(error) {
        case .current:
            availableVersion = nil
            phase = .current
        case .unavailable(let message):
            availableVersion = nil
            phase = .unavailable(message: message)
        case .cancelled: restoreAvailableUpdate()
        case .failed(let message): phase = .failed(message: message)
        }
    }

    private func restoreAvailableUpdate() {
        phase = availableVersion.map { .updateAvailable(version: $0) } ?? .ready
    }
}
