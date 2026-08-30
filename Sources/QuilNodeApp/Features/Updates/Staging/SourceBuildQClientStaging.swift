import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func stageSourceQClient(
        context: SourceBuildPipelineContext,
        existing: ManagedQClientStatus?,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> SignedArtifactActivation? {
        let canReuse =
            existing?.isReady == true
            && QClientCompatibility.isCompatible(
                qclientReleaseVersion: existing?.releaseVersion,
                nodeVersion: context.sourceVersion
            )
        if canReuse {
            progress(
                NodeUpdateProgress(
                    step: .client,
                    phase: "Reusing verified qclient",
                    detail:
                        "Installed qclient \(existing?.releaseVersion ?? context.sourceVersion) remains compatible with node runtime \(context.sourceVersion)",
                    fraction: 0.95,
                    startedAt: context.startedAt,
                    isEstimate: false,
                    logURL: context.logURL
                ))
            return nil
        }

        let qclientManifest = context.repository.appendingPathComponent("crates/quil-client/Cargo.toml")
        guard FileManager.default.fileExists(atPath: qclientManifest.path) else { return nil }

        let built = context.repository.appendingPathComponent("target/release/qclient")
        progress(
            NodeUpdateProgress(
                step: .client,
                phase: "Compiling matching qclient",
                detail: "Building the client from the same immutable commit as the node",
                fraction: 0.945,
                startedAt: context.startedAt,
                isEstimate: true,
                logURL: context.logURL
            ))
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: context.sandbox.compileProfile,
                executable: context.sandbox.cargoExecutable,
                arguments: ["build", "--release", "--package", "quil-client"]
            ),
            currentDirectory: context.repository,
            environment: context.sandbox.environment,
            timeout: 3 * 60 * 60,
            logURL: context.logURL
        )
        try verifyPinnedCheckoutIsUnmodified(
            context.repository,
            hydratedSeniorityDataset: context.seniorityDataset
        )
        try validateSourceBuildArtifact(built, maximumBytes: 250_000_000)

        let shortCommit = String(context.head.commit.prefix(8))
        let fileName = "qclient-\(context.sourceVersion)-source-\(shortCommit)-darwin-arm64"
        let staged = context.directory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: built, to: staged)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
        let versionOutput = try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: context.sandbox.compileProfile,
                executable: built.path,
                arguments: ["-y", "version"]
            ),
            currentDirectory: context.repository,
            environment: context.sandbox.environment,
            timeout: 15
        )
        guard let runtimeVersion = QClientRuntimeVersionParser.parse(versionOutput),
            let hash = sha256(of: staged)
        else { throw UpdateCenterError.versionValidationFailed }

        let buildInfo = """
            Quilibrium qclient local source build
            Runtime version: \(runtimeVersion)
            Official repository: \(context.repositoryURL)
            Branch: \(context.head.name)
            Commit: \(context.head.commit)
            Binary SHA-256: \(hash)
            This is NOT an officially signed release binary.
            """
        try buildInfo.data(using: .utf8)?.write(
            to: context.directory.appendingPathComponent("\(fileName).BUILD-INFO.txt"),
            options: .atomic
        )
        return SignedArtifactActivation(
            kind: .qclient,
            trust: .pinnedSource,
            releaseVersion: context.sourceVersion,
            reportedVersion: runtimeVersion,
            binaryFileName: fileName,
            sha256: hash,
            signatureIndices: [],
            branch: context.head.name,
            commit: context.head.commit
        )
    }
}
