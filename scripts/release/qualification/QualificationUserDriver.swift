import Foundation
import Sparkle

/// Noninteractive UI for disposable qualification apps only. Never shipped.
@MainActor
final class QualificationUserDriver: NSObject, SPUUserDriver {
    let mode: String
    var events: [String] = []
    var errorCode: Int?
    var errorDomain: String?
    var errorChain: [[String: Any]] = []
    var finish: (() -> Void)?

    init(mode: String) { self.mode = mode }

    func show(
        _ request: SPUUpdatePermissionRequest,
        reply: @escaping (SUUpdatePermissionResponse) -> Void
    ) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { events.append("checking") }
    func showUpdateFound(
        with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        events.append("found")
        reply(mode == "probe" ? .dismiss : .install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}
    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        record(error)
        events.append("not-found")
        acknowledgement()
    }
    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        record(error)
        events.append("error")
        acknowledgement()
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        events.append("download")
        if mode == "cancel" { cancellation() }
    }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {
        if !events.contains("received-data") { events.append("received-data") }
        // Simulate abrupt app termination without touching any other process.
        if mode == "interrupt" { _exit(75) }
    }
    func showDownloadDidStartExtractingUpdate() { events.append("extracting") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        events.append("ready-to-install")
        reply(.install)
    }
    func showInstallingUpdate(
        withApplicationTerminated applicationTerminated: Bool,
        retryTerminatingApplication: @escaping () -> Void
    ) {
        events.append("installing")
    }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        events.append("installed")
        acknowledgement()
        finish?()
    }
    func dismissUpdateInstallation() { finish?() }
    func showUpdateInFocus() { events.append("focused") }

    private func record(_ error: any Error) {
        errorCode = (error as NSError).code
        errorDomain = (error as NSError).domain
        var next: NSError? = error as NSError
        while let current = next, errorChain.count < 8 {
            errorChain.append(["domain": current.domain, "code": current.code])
            next = current.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        // Fixture diagnostics stay in the private qualification report.
        FileHandle.standardError.write(Data("\(error as NSError)\n".utf8))
    }
}
