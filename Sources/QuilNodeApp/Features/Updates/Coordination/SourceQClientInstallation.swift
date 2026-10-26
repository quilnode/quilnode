import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

@MainActor
extension ReleaseChecker {
    func installSourceQClient(_ snapshot: UpdateCenterSnapshot) async {
        guard operation == .idle else { return }
        let startedAt = Date()
        let head = snapshot.qclientSourceHead
        operation = .building(branch: head?.name ?? "matching client", commit: head?.commit ?? "")
        lastError = nil
        lastMessage = nil
        do {
            let repository = repositoryURL
            let report = progressReporter()
            let worker = Task.detached(priority: .utility) {
                if let head {
                    return try Self.stageStandaloneSourceQClient(
                        installed: snapshot.installed.build, head: head, repositoryURL: repository,
                        startedAt: startedAt, progress: report
                    )
                }
                return try Self.stageMatchingSourceQClient(
                    installed: snapshot.installed.build, repositoryURL: repository,
                    startedAt: startedAt, progress: report
                )
            }
            let manifest = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
            }
            try Task.checkCancellation()
            operation = .awaitingAuthorization
            let result = await Task.detached(priority: .userInitiated) {
                Self.runAuthorizedHelper(
                    arguments: ["qclient-install", manifest.path], durableOperation: true,
                    allowsInteractiveAuthorization: true
                )
            }.value
            guard result.exitCode == 0 else { throw UpdateCenterError.activationFailed(result.output) }
            let status = await Task.detached(priority: .utility) {
                PrivilegedServiceClient.readQClientStatus(timeout: 10)
            }.value
            guard
                QClientCompatibility.isCurrent(
                    status.status, nodeVersion: status.status?.releaseVersion,
                    nodeCommit: head?.commit ?? snapshot.installed.build.commit
                )
            else {
                throw UpdateCenterError.activationFailed(
                    status.error ?? "Client provenance did not match the selected source.")
            }
            progress = NodeUpdateProgress(
                status: .succeeded, workflow: .qclient, step: .switchRuntime,
                phase: "qclient updated",
                detail: "Source client verified. Wallet reads will refresh; the node stayed online.",
                fraction: 1, startedAt: startedAt, isEstimate: false
            )
            lastMessage = result.output
            shouldCheckAfterOperation = true
            await monitor?.refresh(forceNodeInfo: true)
        } catch {
            lastError = error.localizedDescription
            progress = NodeUpdateProgress(
                status: .failed, workflow: .qclient, step: progress?.step ?? .selectCandidate,
                phase: "qclient update stopped", detail: error.localizedDescription,
                fraction: 1, startedAt: startedAt, isEstimate: false
            )
        }
        operation = .idle
    }
}
