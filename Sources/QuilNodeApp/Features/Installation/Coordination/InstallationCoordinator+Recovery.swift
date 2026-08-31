import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Reconnects onboarding to work already owned by the authenticated daemon.
/// The node operation never depends on the window or app process staying open.
@MainActor
extension InstallationCoordinator {
    func start() {
        guard !started else { return }
        started = true
        Task {
            if !(await resumeManagedInstallationIfNeeded()) {
                await refreshPreflight()
            }
        }
    }

    func resumeManagedInstallationIfNeeded() async -> Bool {
        let snapshot = await Task.detached(priority: .utility) {
            PrivilegedServiceClient.runningOperation(timeout: 5)
        }.value
        guard let snapshot,
            snapshot.action == .install || snapshot.action == .qclientInstall
        else { return false }

        let workflow: NodeUpdateWorkflow =
            snapshot.action == .qclientInstall ? .qclient : .signedNode
        phase = .installing
        error = nil
        message = "Reconnected to the installation already running in the secure local service."
        progress = InstallationOperationPresentation.progress(
            for: .init(stage: snapshot.stage, message: snapshot.message),
            workflow: workflow,
            startedAt: snapshot.startedAt
        )

        let result = await Task.detached(priority: .userInitiated) {
            PrivilegedServiceClient.followOperation(
                snapshot,
                timeout: 420,
                progress: { [weak self] update in
                    Task { @MainActor in
                        self?.progress = InstallationOperationPresentation.progress(
                            for: update,
                            workflow: workflow,
                            startedAt: snapshot.startedAt
                        )
                    }
                }
            )
        }.value

        if result.exitCode == 76 {
            phase = .installing
            message = result.output
            return true
        }

        let refreshed = await Task.detached(priority: .utility) {
            InstallationHostInspector.inspect()
        }.value
        preflight = refreshed

        guard result.exitCode == 0 else {
            phase = .failed
            error =
                result.output.isEmpty
                ? "The recovered installation did not complete."
                : result.output
            return true
        }

        let verified =
            snapshot.action == .install
            ? (refreshed.nodeInstalled && refreshed.secureServiceReady)
            : (refreshed.qclientStatus?.isReady == true && refreshed.qclientCompatibleWithNode)
        guard verified else {
            phase = .failed
            error = "The installer completed, but its local runtime evidence could not be re-verified."
            return true
        }

        phase = .complete
        progress = NodeUpdateProgress(
            status: .succeeded,
            workflow: workflow,
            step: workflow == .qclient ? .switchRuntime : .healthGate,
            phase: workflow == .qclient ? "qclient ready" : "Node installed",
            detail: result.output,
            fraction: 1,
            startedAt: snapshot.startedAt,
            isEstimate: false
        )
        message = result.output
        if snapshot.action == .install { didCompleteInstallationThisRun = true }
        return true
    }
}
