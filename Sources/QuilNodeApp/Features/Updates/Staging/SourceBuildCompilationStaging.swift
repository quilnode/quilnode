import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func compileAndStageSourceNode(
        context: SourceBuildPipelineContext,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> StagedSourceNodeArtifact {
        progress(
            NodeUpdateProgress(
                step: .resolveDependencies,
                phase: "Resolving locked dependencies",
                detail: "Fetching only the packages pinned by Cargo.lock inside the isolated build home",
                fraction: 0.14,
                startedAt: context.startedAt,
                isEstimate: true,
                logURL: context.logURL
            ))
        // Dependency acquisition may use the network but cannot read the
        // operator home. A failed fetch leaves its bounded transcript intact.
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: context.sandbox.fetchProfile,
                executable: context.sandbox.cargoExecutable,
                arguments: ["fetch", "--locked"]
            ),
            currentDirectory: context.repository,
            environment: context.sandbox.environment,
            timeout: 30 * 60,
            logURL: context.logURL
        )
        progress(
            NodeUpdateProgress(
                step: .compileNode,
                phase: "Compiling node",
                detail: "Cargo and macOS manage parallel work; compatible cached artifacts are reused automatically",
                fraction: 0.16,
                startedAt: context.startedAt,
                isEstimate: true,
                logURL: context.logURL
            ))
        // Compilation uses a second deny-network profile so upstream build
        // scripts cannot scan the LAN or transmit local data.
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: context.sandbox.compileProfile,
                executable: "/bin/bash",
                arguments: [context.buildScript.path]
            ),
            currentDirectory: context.repository,
            environment: context.sandbox.environment,
            timeout: 3 * 60 * 60,
            logURL: context.logURL
        ) { log in
            progress(
                sourceBuildProgress(
                    log: log,
                    startedAt: context.startedAt,
                    logURL: context.logURL
                ))
        }

        progress(
            NodeUpdateProgress(
                step: .inspectArtifact,
                phase: "Checking built binary",
                detail: "Confirming output, version, and executable permissions",
                fraction: 0.94,
                startedAt: context.startedAt,
                isEstimate: false
            ))
        try verifyPinnedCheckoutIsUnmodified(
            context.repository,
            hydratedSeniorityDataset: context.seniorityDataset
        )

        let built = context.repository.appendingPathComponent("node/build/arm64_macos/node")
        try validateSourceBuildArtifact(built, maximumBytes: 600_000_000)
        let shortCommit = String(context.head.commit.prefix(8))
        let fileName = "node-\(context.displayVersion)-source-\(shortCommit)-darwin-arm64"
        let staged = context.directory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: built, to: staged)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)

        let versionOutput = try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: context.sandbox.compileProfile,
                executable: built.path,
                arguments: ["--version"]
            ),
            currentDirectory: context.repository,
            environment: context.sandbox.environment,
            timeout: 10
        )
        guard versionOutput.contains(context.sourceVersion) else {
            throw UpdateCenterError.versionValidationFailed
        }
        guard let hash = sha256(of: staged) else { throw UpdateCenterError.hashFailed }
        return StagedSourceNodeArtifact(url: staged, fileName: fileName, sha256: hash)
    }
}
