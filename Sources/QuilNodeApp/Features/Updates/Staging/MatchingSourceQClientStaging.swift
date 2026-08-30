import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func stageMatchingSourceQClient(
        installed: InstalledNodeBuild,
        repositoryURL: String,
        startedAt: Date,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        guard installed.kind == .source,
            let shortCommit = installed.commit,
            let version = installed.version
        else { throw UpdateCenterError.matchingSourceCheckoutUnavailable }
        let workspaceRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/QuilNode/BuildWorkspaces", isDirectory: true)
        let candidates =
            (try? FileManager.default.contentsOfDirectory(
                at: workspaceRoot, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
        var selected: (repository: URL, commit: String)?
        for candidate in candidates where candidate.lastPathComponent.hasPrefix("source-") {
            let repository = candidate.appendingPathComponent("repo", isDirectory: true)
            guard FileManager.default.fileExists(atPath: repository.appendingPathComponent(".git").path),
                let origin = try? runChecked(gitExecutable, ["-C", repository.path, "remote", "get-url", "origin"])
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                origin == repositoryURL,
                let commit = try? runChecked(gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"])
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                commit.hasPrefix(shortCommit)
            else { continue }
            selected = (repository, commit)
            break
        }
        guard let selected else { throw UpdateCenterError.matchingSourceCheckoutUnavailable }
        let seniorityDataset = try prepareSeniorityDataset(in: selected.repository)
        try verifyPinnedCheckoutIsUnmodified(
            selected.repository,
            hydratedSeniorityDataset: seniorityDataset
        )
        let clientManifest = selected.repository.appendingPathComponent("crates/quil-client/Cargo.toml")
        guard FileManager.default.fileExists(atPath: clientManifest.path) else {
            throw UpdateCenterError.sourceQClientMissing
        }
        let built = selected.repository.appendingPathComponent("target/release/qclient")
        let directory = try newStagingDirectory(prefix: "qclient-source-\(shortCommit)")
        let logURL = directory.appendingPathComponent("build.log")
        let workspace = selected.repository.deletingLastPathComponent()
        let sandbox = try prepareSourceBuildSandbox(
            workspace: workspace,
            repository: selected.repository
        )
        progress(
            NodeUpdateProgress(
                step: .resolveDependencies,
                phase: "Resolving locked qclient dependencies",
                detail: "Pinned to the installed node commit \(selected.commit.prefix(12))",
                fraction: 0.08, startedAt: startedAt, isEstimate: true, logURL: logURL
            ))
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.fetchProfile,
                executable: sandbox.cargoExecutable,
                arguments: ["fetch", "--locked"]
            ),
            currentDirectory: selected.repository,
            environment: sandbox.environment,
            timeout: 30 * 60,
            logURL: logURL
        )
        progress(
            NodeUpdateProgress(
                step: .client,
                phase: "Compiling matching qclient",
                detail: "Building from the same immutable commit as the installed source node",
                fraction: 0.16, startedAt: startedAt, isEstimate: true, logURL: logURL
            ))
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile,
                executable: sandbox.cargoExecutable,
                arguments: ["build", "--release", "--package", "quil-client"]
            ),
            currentDirectory: selected.repository, environment: sandbox.environment,
            timeout: 3 * 60 * 60, logURL: logURL
        )
        try verifyPinnedCheckoutIsUnmodified(
            selected.repository,
            hydratedSeniorityDataset: seniorityDataset
        )
        try validateSourceBuildArtifact(built, maximumBytes: 250_000_000)
        let output = try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile,
                executable: built.path,
                arguments: ["-y", "version"]
            ),
            currentDirectory: selected.repository,
            environment: sandbox.environment,
            timeout: 15
        )
        guard let runtime = QClientRuntimeVersionParser.parse(output) else {
            throw UpdateCenterError.versionValidationFailed
        }
        let fileName = "qclient-\(version)-source-\(selected.commit.prefix(8))-darwin-arm64"
        let staged = directory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: built, to: staged)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
        guard let hash = sha256(of: staged) else {
            throw UpdateCenterError.versionValidationFailed
        }
        let branch = "detached-\(selected.commit.prefix(8))"
        let info = """
            Quilibrium qclient local source build
            Runtime version: \(runtime)
            Official repository: \(repositoryURL)
            Commit: \(selected.commit)
            Binary SHA-256: \(hash)
            This is NOT an officially signed release binary.
            """
        try info.data(using: .utf8)?.write(
            to: directory.appendingPathComponent("\(fileName).BUILD-INFO.txt"),
            options: .atomic
        )
        let artifact = SignedArtifactActivation(
            kind: .qclient, trust: .pinnedSource,
            releaseVersion: version, reportedVersion: runtime,
            binaryFileName: fileName, sha256: hash, signatureIndices: [],
            branch: branch, commit: selected.commit
        )
        progress(
            NodeUpdateProgress(
                step: .inspectArtifact,
                phase: "Matching qclient verified",
                detail: "Runtime \(runtime) · SHA-256 recorded · exact source commit retained",
                fraction: 0.96, startedAt: startedAt, isEstimate: false, logURL: logURL
            ))
        return try writeTypedManifest(
            QClientActivationManifest(qclient: artifact),
            named: "qclient-install.json", directory: directory
        )
    }
}
