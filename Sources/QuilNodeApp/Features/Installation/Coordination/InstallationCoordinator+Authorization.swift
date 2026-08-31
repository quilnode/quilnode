import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

@MainActor
extension InstallationCoordinator {
    func authorizeExistingInstallation() async {
        guard requiresPlatformAuthorization, !isWorking else { return }
        let startedAt = Date()
        phase = .authorizing
        error = nil
        message = nil
        progress = NodeUpdateProgress(
            workflow: .signedNode,
            step: .sealPlan,
            phase: "Waiting for macOS authorization",
            detail: OnboardingWaitPresentation.platformAuthorizationGuidance,
            fraction: 0,
            startedAt: startedAt,
            isEstimate: true
        )
        let result = await Task.detached(priority: .userInitiated) {
            ReleaseChecker.authorizeServiceMigration(controllerUID: getuid())
        }.value
        if result.exitCode == -128 {
            phase = .ready
            progress = nil
            message = "Authorization was cancelled. The running node, identity, and stores were not changed."
            return
        }
        guard result.exitCode == 0 else {
            markFailure(result.output.isEmpty ? "The secure local service could not be upgraded." : result.output)
            return
        }
        var refreshed = await Task.detached(priority: .utility) {
            InstallationHostInspector.inspect()
        }.value
        for _ in 0..<10 where !refreshed.secureServiceReady {
            try? await Task.sleep(for: .milliseconds(500))
            refreshed = await Task.detached(priority: .utility) {
                InstallationHostInspector.inspect()
            }.value
        }
        preflight = refreshed
        if refreshed.nodeInstalled && refreshed.secureServiceReady {
            let clientReady =
                refreshed.qclientStatus?.isReady == true
                && refreshed.qclientCompatibleWithNode
            phase = clientReady ? .complete : .ready
            progress = NodeUpdateProgress(
                status: .succeeded,
                workflow: .signedNode,
                step: .sealPlan,
                phase: "Local service authorized",
                detail: "The code-signature-pinned service passed its capability check.",
                fraction: 1,
                startedAt: startedAt,
                isEstimate: false
            )
            message =
                clientReady
                ? "The secure local service is current. Supported platform operations are passwordless."
                : "The secure local service is current. QuilNode can now install the qclient that matches this node without another password prompt."
        } else {
            markFailure(
                "macOS completed authorization, but the upgraded local service could not be verified."
            )
        }
    }
}
