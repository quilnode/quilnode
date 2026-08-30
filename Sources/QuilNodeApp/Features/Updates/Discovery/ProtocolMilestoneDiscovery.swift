import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    /// Discovers operator-relevant frame gates from executable declarations in
    /// the exact official branch commit. Comments are retained as provenance,
    /// while only divergent executable declarations create a conflict.
    nonisolated static func scanProtocolMilestones(
        head: GitBranchHead,
        installed: InstalledNodeBuild,
        cacheURL: URL,
        previous: [ProtocolMilestone]
    ) throws -> [ProtocolMilestone] {
        let discovered: [ProtocolMilestone]
        if let checkout = sourceWorkspace(matching: head.commit) {
            discovered = try protocolMilestones(
                in: checkout,
                at: head.commit,
                branch: head.name,
                committedAt: head.committedAt
            )
        } else {
            discovered = try incrementalProtocolMilestones(
                head: head,
                cacheURL: cacheURL,
                previous: previous
            )
        }
        var installedValues: [String: UInt64] = [:]
        if installed.kind == .source, let installedCommit = installed.commit {
            if let checkout = sourceWorkspace(matching: installedCommit),
                let resolved = try? runChecked(
                    gitExecutable, ["-C", checkout.path, "rev-parse", "HEAD"]
                ).trimmingCharacters(in: .whitespacesAndNewlines),
                let installedMilestones = try? protocolMilestones(
                    in: checkout,
                    at: resolved,
                    branch: "installed",
                    committedAt: head.committedAt
                )
            {
                installedValues = Dictionary(
                    uniqueKeysWithValues: installedMilestones.map { ($0.symbol, $0.targetFrame) }
                )
            }
        }
        return discovered.map { milestone in
            var value = milestone
            if let prior = previous.first(where: { $0.symbol == value.symbol }) {
                if prior.targetFrame != value.targetFrame {
                    value.previousTargetFrame = prior.targetFrame
                } else {
                    value.previousTargetFrame = prior.previousTargetFrame
                }
            }
            if installed.kind == .source {
                value.installedSupport = installedValues[value.symbol] == value.targetFrame ? .included : .missing
            } else {
                value.installedSupport = .unknown
            }
            return value
        }
    }

    /// A complete checkout has all blobs locally, so one bounded `git grep` is
    /// both faster and more complete than materializing a partial-clone cache.
    nonisolated static func protocolMilestones(
        in repository: URL,
        at commit: String,
        branch: String,
        committedAt: Date
    ) throws -> [ProtocolMilestone] {
        let declarationPattern = "pub const [A-Z0-9_]*(RESET|CUTOVER|AMNESTY|ACTIVATION|MIGRATION)[A-Z0-9_]*_FRAME"
        let definitionOutput = try runChecked(
            gitExecutable,
            [
                "-C", repository.path, "grep", "-l", "-E", declarationPattern,
                commit, "--", ":(glob)crates/**/*.rs",
            ]
        )
        var paths = Set(gitGrepPaths(definitionOutput, revision: commit))
        var files = try paths.map { path in
            ProtocolSourceFile(
                path: path,
                contents: try readGitBlob(repository: repository, commit: commit, path: path)
            )
        }
        let preliminary = ProtocolMilestoneDetector.detect(
            files: files,
            branch: branch,
            commit: commit,
            committedAt: committedAt
        )

        // Pull case-insensitive references to each identifier as well as its
        // declaration. Rust call sites use the lowercased function form, and
        // those files often carry the most useful scheduling comments.
        for milestone in preliminary {
            guard
                let references = try? runChecked(
                    gitExecutable,
                    [
                        "-C", repository.path, "grep", "-l", "-i", "-F", milestone.symbol,
                        commit, "--", ":(glob)crates/**/*.rs",
                    ]
                )
            else { continue }
            for path in gitGrepPaths(references, revision: commit) {
                guard paths.insert(path).inserted else { continue }
                files.append(
                    ProtocolSourceFile(
                        path: path,
                        contents: try readGitBlob(repository: repository, commit: commit, path: path)
                    )
                )
            }
        }
        return ProtocolMilestoneDetector.detect(
            files: files,
            branch: branch,
            commit: commit,
            committedAt: committedAt
        )
    }

    nonisolated static func gitGrepPaths(_ output: String, revision: String) -> [String] {
        let prefix = revision + ":"
        return output.split(whereSeparator: \.isNewline).map { raw in
            let value = String(raw)
            return value.hasPrefix(prefix) ? String(value.dropFirst(prefix.count)) : value
        }
    }

    /// When an upstream head has not been built on this Mac yet, materialize
    /// the bounded source plan through a sparse checkout. Git bulk-prefetches
    /// its missing blobs instead of opening one network request per file.
    nonisolated static func incrementalProtocolMilestones(
        head: GitBranchHead,
        cacheURL: URL,
        previous: [ProtocolMilestone]
    ) throws -> [ProtocolMilestone] {
        let files = try materializedProtocolSourceFiles(
            head: head,
            cacheURL: cacheURL,
            previous: previous
        )
        let detected = ProtocolMilestoneDetector.detect(
            files: files,
            branch: head.name,
            commit: head.commit,
            committedAt: head.committedAt
        )
        guard !detected.isEmpty else { throw UpdateCenterError.noProtocolMilestones }
        return detected
    }

    nonisolated static func sourceWorkspace(matching commit: String) -> URL? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/QuilNode/BuildWorkspaces", isDirectory: true)
        guard
            let directories = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else { return nil }
        for directory in directories where directory.lastPathComponent.hasPrefix("source-") {
            let repository = directory.appendingPathComponent("repo", isDirectory: true)
            guard FileManager.default.fileExists(atPath: repository.appendingPathComponent(".git").path),
                let head = try? runChecked(
                    gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"], timeout: 3
                ).trimmingCharacters(in: .whitespacesAndNewlines),
                head.hasPrefix(commit) || commit.hasPrefix(head)
            else { continue }
            return repository
        }
        return nil
    }

    /// `Process` pipes can block when a source blob exceeds the kernel buffer
    /// and the parent waits before draining it. Stream large blobs to an
    /// isolated temporary file, then read them after Git exits.
    nonisolated static func readGitBlob(
        repository: URL,
        commit: String,
        path: String,
        timeout: TimeInterval = 20
    ) throws -> String {
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("quilnode-source-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: output) }
        _ = try runChecked(
            gitExecutable,
            ["-C", repository.path, "show", "\(commit):\(path)"],
            timeout: timeout,
            logURL: output,
            maximumOutputBytes: 2 * 1_024 * 1_024
        )
        return String(
            decoding: try BoundedLocalData.read(
                from: output,
                maximumBytes: 2 * 1_024 * 1_024
            ), as: UTF8.self)
    }
}
