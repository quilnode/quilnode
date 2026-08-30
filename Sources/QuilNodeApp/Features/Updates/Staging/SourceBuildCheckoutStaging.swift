import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension ReleaseChecker {
    nonisolated static func prepareSourceBuildContext(
        head: GitBranchHead,
        repositoryURL: String,
        startedAt: Date,
        channel: String,
        displayVersion: String?,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> SourceBuildPipelineContext {
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
        try prepareSourceRepository(
            repository,
            repositoryURL: repositoryURL,
            head: head,
            startedAt: startedAt,
            progress: progress
        )

        let cargoManifest = repository.appendingPathComponent("crates/quil-node/Cargo.toml")
        let versionSource = repository.appendingPathComponent("crates/quil-config/src/version.rs")
        let buildScript = repository.appendingPathComponent("node/build.sh")
        guard FileManager.default.fileExists(atPath: cargoManifest.path),
            FileManager.default.fileExists(atPath: buildScript.path),
            let sourceVersion = parseNodeVersion(at: versionSource)
        else { throw UpdateCenterError.branchIsNotNodeBuildable(head.name) }

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
        return SourceBuildPipelineContext(
            head: head,
            repositoryURL: repositoryURL,
            startedAt: startedAt,
            channel: channel,
            directory: directory,
            workspace: workspace,
            repository: repository,
            buildScript: buildScript,
            sourceVersion: sourceVersion,
            displayVersion: displayVersion ?? sourceVersion,
            seniorityDataset: seniorityDataset,
            logURL: logURL,
            sandbox: sandbox
        )
    }

    nonisolated private static func prepareSourceRepository(
        _ repository: URL,
        repositoryURL: String,
        head: GitBranchHead,
        startedAt: Date,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws {
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
        // Reconstruct everything except Cargo's stable artifact cache so files
        // generated by an older checkout cannot influence this candidate.
        try runChecked(
            gitExecutable,
            ["-C", repository.path, "clean", "-q", "-f", "-f", "-d", "-x", "-e", "target/"],
            timeout: 90
        )
        let resolvedCommit = try runChecked(
            gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedCommit == head.commit else { throw UpdateCenterError.commitValidationFailed }
    }
}
