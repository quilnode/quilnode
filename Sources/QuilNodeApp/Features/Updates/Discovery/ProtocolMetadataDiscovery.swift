import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated private static let protocolHistoryDepth = 64
    nonisolated private static let protocolRequiredSourcePaths = [
        "crates/quil-execution/src/global_intrinsic/materialize.rs"
    ]

    /// Protocol monitoring owns a separate Git cache so a periodic metadata
    /// refresh can never lock, delay, or invalidate the operator's release
    /// discovery cache.
    nonisolated static func protocolBranchCacheURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("ProtocolBranchCache.git", isDirectory: true)
    }

    /// Refreshes only the refs and history required by protocol monitoring.
    /// Release manifests, approval markers, qclient, and installed-build
    /// comparison deliberately do not participate in this background path.
    nonisolated static func refreshProtocolHead(
        repositoryURL: String,
        cacheURL: URL
    ) throws -> GitBranchHead {
        let fm = FileManager.default
        try fm.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: cacheURL.appendingPathComponent("HEAD").path) {
            try runChecked(gitExecutable, ["init", "--bare", "-q", cacheURL.path], timeout: 15)
            try runChecked(gitExecutable, ["-C", cacheURL.path, "remote", "add", "origin", repositoryURL], timeout: 15)
        } else {
            try runChecked(
                gitExecutable, ["-C", cacheURL.path, "remote", "set-url", "origin", repositoryURL], timeout: 15)
        }

        try runGitFetch(
            repository: cacheURL,
            arguments: [
                "--prune", "--depth=1", "--filter=tree:0", "origin",
                "+refs/heads/*:refs/heads/*",
            ],
            timeout: 45
        )
        let initial = try highestCachedVersionHead(cacheURL: cacheURL)
        try runGitFetch(
            repository: cacheURL,
            arguments: [
                "--depth=\(protocolHistoryDepth)", "--filter=blob:none", "origin",
                "+refs/heads/\(initial.name):refs/heads/\(initial.name)",
            ],
            timeout: 60
        )
        return try highestCachedVersionHead(cacheURL: cacheURL)
    }

    /// Materializes every selected source blob in one sparse checkout. Git's
    /// checkout machinery bulk-prefetches missing blobs, avoiding hundreds of
    /// one-object network round trips from a partial clone.
    nonisolated static func materializedProtocolSourceFiles(
        head: GitBranchHead,
        cacheURL: URL,
        previous: [ProtocolMilestone]
    ) throws -> [ProtocolSourceFile] {
        let changedOutput = try runChecked(
            gitExecutable,
            [
                "-C", cacheURL.path, "log", "--format=", "--name-only",
                "-\(protocolHistoryDepth)", head.commit, "--", ":(glob)crates/**/*.rs",
            ],
            timeout: 20
        )
        let changed =
            changedOutput
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        let paths = ProtocolSourcePlan.paths(
            previous: previous.map(\.sourcePath),
            recentlyChanged: changed,
            required: protocolRequiredSourcePaths
        )
        guard !paths.isEmpty else { throw ProtocolMetadataDiscoveryError.noEligibleSources }

        let fm = FileManager.default
        let workspaceRoot = try applicationSupportDirectory()
            .appendingPathComponent("ProtocolMilestoneWorkspaces", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let checkout = workspaceRoot.appendingPathComponent("checkout", isDirectory: true)
        try fm.createDirectory(at: workspaceRoot, withIntermediateDirectories: true)
        defer {
            _ = try? runChecked(
                gitExecutable,
                ["-C", cacheURL.path, "worktree", "remove", "--force", checkout.path],
                timeout: 15,
                honorsCancellation: false
            )
            try? fm.removeItem(at: workspaceRoot)
        }

        try runChecked(
            gitExecutable,
            ["-C", cacheURL.path, "worktree", "add", "--detach", "--no-checkout", checkout.path, head.commit],
            timeout: 20
        )
        try runChecked(gitExecutable, ["-C", checkout.path, "sparse-checkout", "init", "--no-cone"], timeout: 10)
        try runChecked(
            gitExecutable,
            ["-C", checkout.path, "sparse-checkout", "set", "--no-cone"] + paths,
            timeout: 20
        )
        try runChecked(
            gitExecutable,
            ["-C", checkout.path, "checkout", "--detach", "-q", head.commit],
            timeout: 60
        )

        let maximumSourceBytes = 2_000_000
        let maximumTotalSourceBytes = 24_000_000
        var totalSourceBytes = 0
        var files: [ProtocolSourceFile] = []
        for path in paths {
            let url = checkout.appendingPathComponent(path)
            guard fm.fileExists(atPath: url.path) else { continue }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true,
                let size = values.fileSize,
                size > 0,
                size <= maximumSourceBytes,
                totalSourceBytes + size <= maximumTotalSourceBytes
            else { continue }
            totalSourceBytes += size
            let data = try BoundedLocalData.read(from: url, maximumBytes: maximumSourceBytes)
            files.append(ProtocolSourceFile(path: path, contents: String(decoding: data, as: UTF8.self)))
        }
        guard !files.isEmpty else { throw ProtocolMetadataDiscoveryError.noReadableSources }
        return files
    }
}

private enum ProtocolMetadataDiscoveryError: LocalizedError {
    case noEligibleSources
    case noReadableSources

    var errorDescription: String? {
        switch self {
        case .noEligibleSources: "No safe protocol source paths were found."
        case .noReadableSources: "Protocol source files could not be materialized."
        }
    }
}
