import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func stageSourceBuild(
        head: GitBranchHead,
        repositoryURL: String,
        startedAt: Date,
        channel: String,
        displayVersion: String?,
        existingQClient: ManagedQClientStatus?,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        guard
            ["/opt/homebrew/bin/git-lfs", "/usr/local/bin/git-lfs"].contains(where: {
                FileManager.default.isExecutableFile(atPath: $0)
            })
        else {
            throw UpdateCenterError.sourceToolMissing("Git LFS")
        }
        let directory = try newStagingDirectory(prefix: "source-\(head.commit.prefix(8))")
        let workspace = try sourceBuildWorkspace(
            cacheDomain: channel == "approved-dev" ? "approved" : "raw",
            legacyCommit: head.commit
        )
        let repository = workspace.appendingPathComponent("repo", isDirectory: true)
        let gitDirectory = repository.appendingPathComponent(".git", isDirectory: true)
        if FileManager.default.fileExists(atPath: gitDirectory.path) {
            let origin = try runChecked(
                gitExecutable, ["-C", repository.path, "remote", "get-url", "origin"]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            guard origin == repositoryURL else { throw UpdateCenterError.sourceCacheInvalid }
            progress(
                NodeUpdateProgress(
                    step: .acquire,
                    phase: "Reusing local build cache",
                    detail: "Previously compiled packages for \(head.commit.prefix(8)) will be reused",
                    fraction: 0.04,
                    startedAt: startedAt,
                    isEstimate: true
                ))
        } else {
            progress(
                NodeUpdateProgress(
                    step: .acquire,
                    phase: "Cloning official repository",
                    detail: "Creating a clean local checkout with no source modifications",
                    fraction: 0.03,
                    startedAt: startedAt,
                    isEstimate: true
                ))
            try runChecked(
                gitExecutable,
                ["clone", "-q", "--filter=blob:none", "--no-checkout", repositoryURL, repository.path],
                timeout: 180
            )
        }
        progress(
            NodeUpdateProgress(
                step: .acquire,
                phase: "Fetching pinned commit",
                detail: "\(head.name) · \(head.commit.prefix(12))",
                fraction: 0.06,
                startedAt: startedAt,
                isEstimate: true
            ))
        try runGitFetch(
            repository: repository,
            arguments: ["--depth=1", "--filter=blob:none", "origin", head.commit],
            timeout: 180
        )
        progress(
            NodeUpdateProgress(
                step: .acquire,
                phase: "Checking out source",
                detail: "Verifying that HEAD resolves to the selected immutable commit",
                fraction: 0.09,
                startedAt: startedAt,
                isEstimate: true
            ))
        try runChecked(
            gitExecutable, ["-C", repository.path, "checkout", "-q", "-f", "--detach", head.commit],
            timeout: 90
        )
        // Preserve only Cargo's stable artifact cache. Everything else must be
        // reconstructed from the selected commit so an ignored/generated file
        // from an older source build cannot influence the next candidate.
        try runChecked(
            gitExecutable,
            ["-C", repository.path, "clean", "-q", "-f", "-f", "-d", "-x", "-e", "target/"],
            timeout: 90
        )
        let resolvedCommit = try runChecked(
            gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedCommit == head.commit else { throw UpdateCenterError.commitValidationFailed }

        let cargoManifest = repository.appendingPathComponent("crates/quil-node/Cargo.toml")
        let versionSource = repository.appendingPathComponent("crates/quil-config/src/version.rs")
        let buildScript = repository.appendingPathComponent("node/build.sh")
        guard FileManager.default.fileExists(atPath: cargoManifest.path),
            FileManager.default.fileExists(atPath: buildScript.path),
            let sourceVersion = parseNodeVersion(at: versionSource)
        else { throw UpdateCenterError.branchIsNotNodeBuildable(head.name) }
        let version = displayVersion ?? sourceVersion

        if try prepareBuildCache(workspace: workspace, repository: repository) {
            progress(
                NodeUpdateProgress(
                    step: .acquire,
                    phase: "Resetting relocated build cache",
                    detail: "Removing stale compiler metadata that referenced the previous build path",
                    fraction: 0.11,
                    startedAt: startedAt,
                    isEstimate: true
                ))
        }
        progress(
            NodeUpdateProgress(
                step: .verifyTrust,
                phase: "Preparing seniority dataset",
                detail: "Hydrating the exact object committed by upstream and verifying its SHA-256",
                fraction: 0.12,
                startedAt: startedAt,
                isEstimate: true
            ))
        let seniorityDataset = try prepareSeniorityDataset(in: repository)
        try verifyPinnedCheckoutIsUnmodified(
            repository,
            hydratedSeniorityDataset: seniorityDataset
        )

        let logURL = directory.appendingPathComponent("build.log")
        let sandbox = try prepareSourceBuildSandbox(
            workspace: workspace,
            repository: repository
        )
        let packageCount = cargoPackageCount(in: repository)
        let cachedUnits = cachedCompileUnits(in: repository, maximum: packageCount)
        progress(
            NodeUpdateProgress(
                step: .acquire,
                phase: "Resolving locked dependencies",
                detail: "Fetching only the packages pinned by Cargo.lock inside the isolated build home",
                fraction: 0.14,
                startedAt: startedAt,
                isEstimate: true,
                logURL: logURL
            ))
        // Fetching has a bounded log of its own. A successful compile replaces
        // this short acquisition transcript; a failed fetch leaves the actual
        // registry, DNS, or TLS cause available in Update Center.
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.fetchProfile,
                executable: sandbox.cargoExecutable,
                arguments: ["fetch", "--locked"]
            ),
            currentDirectory: repository,
            environment: sandbox.environment,
            timeout: 30 * 60,
            logURL: logURL
        )
        progress(
            NodeUpdateProgress(
                step: .compileNode,
                phase: "Compiling node",
                detail: cachedUnits > 0
                    ? "Reusing about \(cachedUnits) cached compile units; Cargo will rebuild only what changed"
                    : "Starting Cargo with four parallel jobs",
                fraction: 0.16 + (Double(cachedUnits) / Double(packageCount)) * 0.72,
                startedAt: startedAt,
                completedUnits: cachedUnits,
                totalUnits: packageCount,
                isEstimate: true,
                logURL: logURL
            ))
        // Resolve dependencies with networking enabled but the operator's home
        // still unreadable. Compilation then uses a second deny-network profile
        // so upstream build scripts cannot scan the LAN or exfiltrate data.
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile,
                executable: "/bin/bash",
                arguments: [buildScript.path]
            ),
            currentDirectory: repository,
            environment: sandbox.environment,
            timeout: 3 * 60 * 60,
            logURL: logURL
        ) { log in
            progress(
                sourceBuildProgress(
                    log: log, packageCount: packageCount, repository: repository,
                    startedAt: startedAt, logURL: logURL
                ))
        }

        progress(
            NodeUpdateProgress(
                step: .inspectArtifact,
                phase: "Checking built binary",
                detail: "Confirming output, version, and executable permissions",
                fraction: 0.94,
                startedAt: startedAt,
                isEstimate: false
            ))

        try verifyPinnedCheckoutIsUnmodified(
            repository,
            hydratedSeniorityDataset: seniorityDataset
        )
        let built = repository.appendingPathComponent("node/build/arm64_macos/node")
        try validateSourceBuildArtifact(built, maximumBytes: 600_000_000)
        let shortCommit = String(head.commit.prefix(8))
        let filename = "node-\(version)-source-\(shortCommit)-darwin-arm64"
        let staged = directory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: built, to: staged)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
        let nodeVersionOutput = try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile,
                executable: built.path,
                arguments: ["--version"]
            ),
            currentDirectory: repository,
            environment: sandbox.environment,
            timeout: 10
        )
        guard nodeVersionOutput.contains(sourceVersion) else {
            throw UpdateCenterError.versionValidationFailed
        }
        guard let hash = sha256(of: staged) else { throw UpdateCenterError.hashFailed }

        var qclientArtifact: SignedArtifactActivation?
        let qclientManifest = repository.appendingPathComponent("crates/quil-client/Cargo.toml")
        let canReuseQClient =
            existingQClient?.isReady == true
            && QClientCompatibility.isCompatible(
                qclientReleaseVersion: existingQClient?.releaseVersion,
                nodeVersion: sourceVersion
            )
        if canReuseQClient {
            progress(
                NodeUpdateProgress(
                    step: .client,
                    phase: "Reusing verified qclient",
                    detail:
                        "Installed qclient \(existingQClient?.releaseVersion ?? sourceVersion) remains compatible with node runtime \(sourceVersion)",
                    fraction: 0.95, startedAt: startedAt,
                    isEstimate: false, logURL: logURL
                ))
        } else if FileManager.default.fileExists(atPath: qclientManifest.path) {
            let builtQClient = repository.appendingPathComponent("target/release/qclient")
            progress(
                NodeUpdateProgress(
                    step: .client,
                    phase: "Compiling matching qclient",
                    detail: "Building the client from the same immutable commit as the node",
                    fraction: 0.945, startedAt: startedAt,
                    isEstimate: true, logURL: logURL
                ))
            try runChecked(
                SourceBuildSandbox.executable,
                try SourceBuildSandbox.arguments(
                    profileURL: sandbox.compileProfile,
                    executable: sandbox.cargoExecutable,
                    arguments: ["build", "--release", "--package", "quil-client"]
                ),
                currentDirectory: repository,
                environment: sandbox.environment,
                timeout: 3 * 60 * 60,
                logURL: logURL
            )
            try verifyPinnedCheckoutIsUnmodified(
                repository,
                hydratedSeniorityDataset: seniorityDataset
            )
            try validateSourceBuildArtifact(builtQClient, maximumBytes: 250_000_000)
            let qclientName = "qclient-\(sourceVersion)-source-\(shortCommit)-darwin-arm64"
            let stagedQClient = directory.appendingPathComponent(qclientName)
            try FileManager.default.copyItem(at: builtQClient, to: stagedQClient)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stagedQClient.path)
            let qclientVersionOutput = try runChecked(
                SourceBuildSandbox.executable,
                try SourceBuildSandbox.arguments(
                    profileURL: sandbox.compileProfile,
                    executable: builtQClient.path,
                    arguments: ["-y", "version"]
                ),
                currentDirectory: repository,
                environment: sandbox.environment,
                timeout: 15
            )
            guard let qclientRuntimeVersion = QClientRuntimeVersionParser.parse(qclientVersionOutput),
                let qclientHash = sha256(of: stagedQClient)
            else { throw UpdateCenterError.versionValidationFailed }
            let qclientBuildInfo = """
                Quilibrium qclient local source build
                Runtime version: \(qclientRuntimeVersion)
                Official repository: \(repositoryURL)
                Branch: \(head.name)
                Commit: \(head.commit)
                Binary SHA-256: \(qclientHash)
                This is NOT an officially signed release binary.
                """
            try qclientBuildInfo.data(using: String.Encoding.utf8)?.write(
                to: directory.appendingPathComponent("\(qclientName).BUILD-INFO.txt"),
                options: Data.WritingOptions.atomic
            )
            qclientArtifact = SignedArtifactActivation(
                kind: .qclient,
                trust: .pinnedSource,
                releaseVersion: sourceVersion,
                reportedVersion: qclientRuntimeVersion,
                binaryFileName: qclientName,
                sha256: qclientHash,
                signatureIndices: [],
                branch: head.name,
                commit: head.commit
            )
        }

        progress(
            NodeUpdateProgress(
                step: .sealPlan,
                phase: "Creating integrity metadata",
                detail: "Calculating SHA-256 and SHA3-256 for the staged binary",
                fraction: 0.96,
                startedAt: startedAt,
                isEstimate: false
            ))
        let sha3 = try bundledSHA3Digest(of: staged)
        let digestLine = "SHA3-256(\(filename))= \(sha3)\n"
        try digestLine.data(using: String.Encoding.utf8)?.write(
            to: directory.appendingPathComponent("\(filename).dgst"),
            options: Data.WritingOptions.atomic
        )

        let buildInfo = """
            Quilibrium \(version) local source build
            Node-reported base version: \(sourceVersion)
            Official repository: \(repositoryURL)
            Branch: \(head.name)
            Commit: \(head.commit)
            Commit time: \(ISO8601DateFormatter().string(from: head.committedAt))
            Commit subject: \(head.subject)
            Official seniority dataset SHA-256: \(seniorityDataset.oid)
            Official seniority dataset bytes: \(seniorityDataset.size)
            Binary SHA-256: \(hash)
            This is NOT an officially signed release binary.
            """
        try buildInfo.data(using: String.Encoding.utf8)?.write(
            to: directory.appendingPathComponent("\(filename).BUILD-INFO.txt"),
            options: Data.WritingOptions.atomic
        )
        let manifest = UpdateActivationManifest(
            channel: channel,
            version: version,
            reportedVersion: sourceVersion,
            branch: head.name,
            commit: head.commit,
            binaryFileName: filename, sha256: hash,
            qclient: qclientArtifact
        )
        return try writeManifest(manifest, directory: directory)
    }
}
