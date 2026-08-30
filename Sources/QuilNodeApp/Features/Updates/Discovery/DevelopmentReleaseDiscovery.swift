import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    /// Resolves approval to the immutable commit that most recently changed
    /// the root `subpatch` marker. Later commits may inherit the file, but are
    /// intentionally not treated as approved until the marker changes again.
    nonisolated static func resolveApprovedDevelopment(
        head: GitBranchHead,
        cacheURL: URL
    ) throws -> ApprovedDevelopmentReleaseInfo? {
        guard let baseVersion = head.version else { return nil }
        try runGitFetch(
            repository: cacheURL,
            arguments: [
                "--depth=512", "--filter=blob:none", "origin",
                "+refs/heads/\(head.name):refs/heads/\(head.name)",
            ],
            timeout: 90
        )

        // If the active branch has removed the marker, there is no currently
        // approved development target even though older history contains one.
        guard
            (try? runChecked(
                gitExecutable, ["-C", cacheURL.path, "cat-file", "-e", "\(head.commit):subpatch"]
            )) != nil
        else { return nil }

        let markerCommit = try runChecked(
            gitExecutable,
            ["-C", cacheURL.path, "log", "-1", "--format=%H", head.commit, "--", "subpatch"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard markerCommit.count == 40, markerCommit.allSatisfy(\.isHexDigit) else { return nil }
        _ = try runChecked(
            gitExecutable,
            ["-C", cacheURL.path, "merge-base", "--is-ancestor", markerCommit, head.commit]
        )
        let markerContents = try runChecked(
            gitExecutable, ["-C", cacheURL.path, "show", "\(markerCommit):subpatch"]
        )
        guard let subpatch = ApprovedDevelopmentMarker.parse(markerContents),
            let version = ApprovedDevelopmentMarker.version(baseVersion: baseVersion, subpatch: subpatch)
        else { return nil }
        let timestampText = try runChecked(
            gitExecutable, ["-C", cacheURL.path, "show", "-s", "--format=%ct", markerCommit]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = try runChecked(
            gitExecutable, ["-C", cacheURL.path, "show", "-s", "--format=%s", markerCommit]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        let aheadText = try runChecked(
            gitExecutable, ["-C", cacheURL.path, "rev-list", "--count", "\(markerCommit)..\(head.commit)"]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let timestamp = TimeInterval(timestampText), let ahead = Int(aheadText) else { return nil }
        return ApprovedDevelopmentReleaseInfo(
            version: version,
            subpatch: subpatch,
            branch: head.name,
            commit: markerCommit.lowercased(),
            committedAt: Date(timeIntervalSince1970: timestamp),
            subject: subject,
            branchHeadCommit: head.commit,
            unapprovedCommitsAhead: ahead
        )
    }

    /// Returns an exact count only when Git proves that the installed source
    /// commit is an ancestor of the selected head. A missing or divergent
    /// commit deliberately remains unknown instead of showing a misleading
    /// "behind" number.
    nonisolated static func commitsBehind(
        installed: InstalledNodeBuild,
        head: GitBranchHead,
        cacheURL: URL
    ) -> Int? {
        guard installed.kind == .source, let installedCommit = installed.commit else { return nil }
        if head.commit.hasPrefix(installedCommit) || installedCommit.hasPrefix(head.commit) { return 0 }

        do {
            // The branch scan is intentionally shallow. Fetch a bounded slice
            // of only the selected head before measuring ancestry.
            try runGitFetch(
                repository: cacheURL,
                arguments: ["--depth=512", "--filter=tree:0", "origin", head.commit],
                timeout: 90
            )
            let resolvedInstalled = try runChecked(
                gitExecutable,
                ["-C", cacheURL.path, "rev-parse", "--verify", "\(installedCommit)^{commit}"]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try runChecked(
                gitExecutable,
                ["-C", cacheURL.path, "merge-base", "--is-ancestor", resolvedInstalled, head.commit]
            )
            let count = try runChecked(
                gitExecutable,
                ["-C", cacheURL.path, "rev-list", "--count", "\(resolvedInstalled)..\(head.commit)"]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(count)
        } catch {
            return nil
        }
    }

    nonisolated static func readInstalledBuild() -> InstalledReleaseInfo {
        let symlink = URL(fileURLWithPath: "/opt/quilibrium/node/quilibrium-node")
        let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: symlink.path)) ?? symlink.path
        let build = InstalledNodeBuildParser.parse(symlinkTarget: target)
        let resolved =
            target.hasPrefix("/")
            ? URL(fileURLWithPath: target)
            : symlink.deletingLastPathComponent().appendingPathComponent(target)
        let attributes = try? FileManager.default.attributesOfItem(atPath: resolved.path)
        return InstalledReleaseInfo(
            build: build,
            sha256: sha256(of: resolved),
            installedFileModifiedAt: attributes?[.modificationDate] as? Date
        )
    }

    nonisolated static func signedReleaseIsNewer(
        _ release: SignedReleaseInfo,
        than installed: InstalledNodeBuild
    ) -> Bool {
        guard let available = NodeVersion(release.version) else { return false }
        guard let currentString = installed.version, let current = NodeVersion(currentString) else { return true }
        return current < available
    }

    nonisolated static func approvedReleaseIsNewer(
        _ release: ApprovedDevelopmentReleaseInfo,
        than installed: InstalledNodeBuild
    ) -> Bool {
        guard let available = NodeVersion(release.version) else { return false }
        guard let currentString = installed.version, let current = NodeVersion(currentString) else { return true }
        return current < available
    }

    nonisolated static func installed(_ installed: InstalledNodeBuild, matches head: GitBranchHead) -> Bool {
        guard installed.kind == .source, let commit = installed.commit else { return false }
        return head.commit.hasPrefix(commit) || commit.hasPrefix(head.commit)
    }
}
