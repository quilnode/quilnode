import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Client repair has its own evidence and authorization boundary.
@MainActor
extension InstallationCoordinator {
    /// Adds or updates qclient for an existing node without stopping it. The
    /// already-authorized root service repeats all trust checks.
    func prepareAndInstallQClient(allowsInteractiveAuthorization: Bool = false) async {
        guard requiresQClientSetup, !isWorking else { return }
        phase = .inspecting
        let current = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
        preflight = current
        guard current.needsQClientRepair else {
            phase = current.qclientStatus?.isReady == true && current.qclientCompatibleWithNode ? .complete : .ready
            message =
                phase == .complete
                ? "The installed wallet client is already verified and compatible."
                : "The wallet client could not be checked. No installation was started."
            return
        }
        guard allowsInteractiveAuthorization || current.canAutomaticallyInstallQClient else {
            phase = .ready
            message = "Review the wallet client repair, then choose Update client to continue."
            return
        }
        error = nil
        message = nil
        let startedAt = Date()
        phase = .downloading
        progress = NodeUpdateProgress(
            workflow: .qclient, step: .selectCandidate,
            phase: "Preparing wallet client", detail: "Finding the current client for the installed protocol",
            fraction: 0, startedAt: startedAt, isEstimate: true
        )
        do {
            let reporter: @Sendable (NodeUpdateProgress) -> Void = { [weak self] update in
                Task { @MainActor in
                    guard let self, [.downloading, .verifying].contains(self.phase) else { return }
                    self.phase = update.phase.localizedCaseInsensitiveContains("verif") ? .verifying : .downloading
                    self.progress = update
                }
            }
            guard let preflightSnapshot = preflight else { return }
            let prepared = try await runCancellablePreparation {
                try await InstallationArtifactPreparation.stageQClient(
                    for: preflightSnapshot,
                    startedAt: startedAt,
                    progress: reporter
                )
            }
            qclientRelease = prepared.officialRelease
            phase = .installing
            progress = NodeUpdateProgress(
                workflow: .qclient,
                step: .switchRuntime,
                phase: "Handing off to local installer",
                detail: prepared.allowsInteractiveAuthorization
                    ? "Confirm the macOS prompt to install the verified source client."
                    : "The verified qclient is ready for the local service.",
                fraction: 0.90,
                startedAt: startedAt,
                isEstimate: false
            )
            let result = await Task.detached(priority: .userInitiated) { [weak self] in
                ReleaseChecker.runAuthorizedHelper(
                    arguments: ["qclient-install", prepared.manifestURL.path],
                    durableOperation: true,
                    allowsInteractiveAuthorization: allowsInteractiveAuthorization
                        && prepared.allowsInteractiveAuthorization,
                    progress: { [weak self] update in
                        Task { @MainActor in
                            self?.progress = InstallationOperationPresentation.progress(
                                for: update,
                                workflow: .qclient,
                                startedAt: startedAt
                            )
                        }
                    }
                )
            }.value
            guard result.exitCode == 0 else {
                markFailure(
                    result.output.isEmpty
                        ? "The qclient installation did not complete."
                        : result.output
                )
                return
            }
            let refreshed = await Task.detached(priority: .utility) { InstallationHostInspector.inspect() }.value
            preflight = refreshed
            guard refreshed.qclientStatus?.isReady == true,
                refreshed.qclientCompatibleWithNode
            else {
                markFailure(
                    "qclient installation returned successfully but its root-owned provenance could not be re-verified."
                )
                return
            }
            phase = .complete
            let isSourceClient = refreshed.qclientStatus?.trust == .pinnedSource
            progress = NodeUpdateProgress(
                status: .succeeded,
                phase: isSourceClient ? "Matching qclient ready" : "Official qclient ready",
                detail: isSourceClient
                    ? "Client commit and version verified; installed without restarting the node"
                    : "Installed separately and signature-verified without restarting the node",
                fraction: 1, startedAt: startedAt, isEstimate: false
            )
            message = result.output
        } catch is CancellationError {
            phase = .ready
            progress = nil
            message = "Client preparation cancelled. Your node is still running; the build cache is retained."
        } catch {
            markFailure(error.localizedDescription)
        }
    }
}
