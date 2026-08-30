import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension ReleaseChecker {
    /// Executes a fail-closed source update pipeline. Each phase returns a
    /// bounded value consumed by the next phase; activation remains outside
    /// this staging transaction and requires the authenticated local service.
    nonisolated static func stageSourceBuild(
        head: GitBranchHead,
        repositoryURL: String,
        startedAt: Date,
        channel: String,
        displayVersion: String?,
        existingQClient: ManagedQClientStatus?,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        let context = try prepareSourceBuildContext(
            head: head,
            repositoryURL: repositoryURL,
            startedAt: startedAt,
            channel: channel,
            displayVersion: displayVersion,
            progress: progress
        )
        let node = try compileAndStageSourceNode(
            context: context,
            progress: progress
        )
        let qclient = try stageSourceQClient(
            context: context,
            existing: existingQClient,
            progress: progress
        )
        return try sealSourceBuildPlan(
            context: context,
            node: node,
            qclient: qclient,
            progress: progress
        )
    }
}
