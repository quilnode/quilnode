import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func sealSourceBuildPlan(
        context: SourceBuildPipelineContext,
        node: StagedSourceNodeArtifact,
        qclient: SignedArtifactActivation?,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        progress(
            NodeUpdateProgress(
                step: .sealPlan,
                phase: "Creating integrity metadata",
                detail: "Calculating SHA-256 and SHA3-256 for the staged binary",
                fraction: 0.96,
                startedAt: context.startedAt,
                isEstimate: false
            ))

        let sha3 = try bundledSHA3Digest(of: node.url)
        let digestLine = "SHA3-256(\(node.fileName))= \(sha3)\n"
        try digestLine.data(using: .utf8)?.write(
            to: context.directory.appendingPathComponent("\(node.fileName).dgst"),
            options: .atomic
        )

        let buildInfo = """
            Quilibrium \(context.displayVersion) local source build
            Node-reported base version: \(context.sourceVersion)
            Official repository: \(context.repositoryURL)
            Branch: \(context.head.name)
            Commit: \(context.head.commit)
            Commit time: \(ISO8601DateFormatter().string(from: context.head.committedAt))
            Commit subject: \(context.head.subject)
            Official seniority dataset SHA-256: \(context.seniorityDataset.oid)
            Official seniority dataset bytes: \(context.seniorityDataset.size)
            Binary SHA-256: \(node.sha256)
            This is NOT an officially signed release binary.
            """
        try buildInfo.data(using: .utf8)?.write(
            to: context.directory.appendingPathComponent("\(node.fileName).BUILD-INFO.txt"),
            options: .atomic
        )
        let manifest = UpdateActivationManifest(
            channel: context.channel,
            version: context.displayVersion,
            reportedVersion: context.sourceVersion,
            branch: context.head.name,
            commit: context.head.commit,
            binaryFileName: node.fileName,
            sha256: node.sha256,
            qclient: qclient
        )
        return try writeManifest(manifest, directory: context.directory)
    }
}
