import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static var seniorityDatasetRelativePath: String {
        "node/execution/intrinsics/global/compat/mainnet_244200_seniority.json"
    }

    nonisolated static func branchCacheURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("BranchCache.git", isDirectory: true)
    }

    nonisolated static func sourceBuildWorkspace(
        cacheDomain: String,
        legacyCommit: String? = nil,
        root overrideRoot: URL? = nil
    ) throws -> URL {
        // Native build scripts persist absolute source paths. A new workspace
        // for every commit therefore defeats Cargo's cache and has previously
        // left generated protobuf paths pointing at deleted directories. Keep
        // one stable, isolated path per trust domain instead: approved builds
        // never consume artifacts produced by the raw-development channel.
        guard ["approved", "raw"].contains(cacheDomain) else {
            throw UpdateCenterError.sourceCacheInvalid
        }
        let fm = FileManager.default
        let root =
            overrideRoot
            ?? fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/QuilNode/BuildWorkspaces", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)

        let marker = root.appendingPathComponent(".\(cacheDomain)-workspace-v1")
        if let selected = try selectedSourceBuildWorkspace(
            from: marker,
            root: root,
            legacyCommit: cacheDomain == "approved" ? legacyCommit : nil,
            fileManager: fm
        ) {
            return selected
        }

        let canonical = root.appendingPathComponent("\(cacheDomain)-source-v1", isDirectory: true)
        try fm.createDirectory(at: canonical, withIntermediateDirectories: true)
        try rememberSourceBuildWorkspace(canonical, marker: marker)
        return canonical
    }

    /// Adopt a healthy legacy per-commit workspace once so an existing operator
    /// does not pay for another cold native build during this cache migration.
    /// New installations always start at the neutral canonical path above.
    nonisolated private static func selectedSourceBuildWorkspace(
        from marker: URL,
        root: URL,
        legacyCommit: String?,
        fileManager fm: FileManager
    ) throws -> URL? {
        if let data = try? BoundedLocalData.read(from: marker, maximumBytes: 256) {
            let name = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard isSafeWorkspaceName(name) else { throw UpdateCenterError.sourceCacheInvalid }
            let selected = root.appendingPathComponent(name, isDirectory: true)
            guard isSafeWorkspaceDirectory(selected) else { throw UpdateCenterError.sourceCacheInvalid }
            return selected
        }

        guard let legacyCommit else { return nil }
        let legacy = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("source-") && isSafeWorkspaceDirectory($0) }
        .filter { candidate in
            let repository = candidate.appendingPathComponent("repo", isDirectory: true)
            let recordedPath = candidate.appendingPathComponent(".repository-path")
            let gitHead = repository.appendingPathComponent(".git/HEAD")
            guard fm.fileExists(atPath: repository.appendingPathComponent(".git").path),
                fm.fileExists(atPath: repository.appendingPathComponent("target").path),
                let data = try? BoundedLocalData.read(from: recordedPath, maximumBytes: 8_192),
                let headData = try? BoundedLocalData.read(from: gitHead, maximumBytes: 256)
            else { return false }
            let recordedRepository = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let detachedHead = String(decoding: headData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return recordedRepository == repository.standardizedFileURL.path
                && detachedHead == legacyCommit
        }
        .max { first, second in
            let firstDate =
                (try? first.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let secondDate =
                (try? second.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return firstDate < secondDate
        }

        if let legacy {
            try rememberSourceBuildWorkspace(legacy, marker: marker)
        }
        return legacy
    }

    nonisolated private static func rememberSourceBuildWorkspace(_ workspace: URL, marker: URL) throws {
        try Data((workspace.lastPathComponent + "\n").utf8).write(to: marker, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: marker.path)
    }

    nonisolated private static func isSafeWorkspaceName(_ name: String) -> Bool {
        !name.isEmpty && name.count <= 80
            && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    nonisolated private static func isSafeWorkspaceDirectory(_ url: URL) -> Bool {
        var metadata = stat()
        return lstat(url.path, &metadata) == 0
            && metadata.st_mode & S_IFMT == S_IFDIR
            && metadata.st_uid == getuid()
            && metadata.st_mode & 0o022 == 0
    }

    /// Cargo build scripts cache absolute source paths. A cache moved from an older
    /// workspace can therefore look valid while pointing `protoc` and native builds
    /// at files that no longer exist. Reset only generated `target/` data when the
    /// recorded repository path changes; subsequent builds at the stable path reuse it.
    nonisolated static func prepareBuildCache(workspace: URL, repository: URL) throws -> Bool {
        let marker = workspace.appendingPathComponent(".repository-path")
        let currentPath = repository.standardizedFileURL.path
        let previousPath = (try? BoundedLocalData.read(from: marker, maximumBytes: 8_192))
            .map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) }
        let target = repository.appendingPathComponent("target", isDirectory: true)
        var reset = false
        if FileManager.default.fileExists(atPath: target.path), previousPath != currentPath {
            try FileManager.default.removeItem(at: target)
            reset = true
        }
        try Data((currentPath + "\n").utf8).write(to: marker, options: [.atomic])
        return reset
    }

    nonisolated static func sourceBuildProgress(
        log: String,
        startedAt: Date,
        logURL: URL
    ) -> NodeUpdateProgress {
        let lines = log.split(whereSeparator: \.isNewline).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        var fraction = 0.32
        var phase = "Compiling node"
        var detail =
            lines.reversed().first(where: {
                $0.hasPrefix("Compiling ") || $0.hasPrefix("Finished ") || $0.hasPrefix("built ")
            }) ?? "Cargo is preparing dependencies"

        let reachedFinalNodeBuild = lines.contains(where: { $0.hasPrefix("Compiling quil-node ") })
        if reachedFinalNodeBuild {
            fraction = 0.89
            phase = "Linking optimized node"
            detail = "Final link-time optimization is active; this stage can be quiet for several minutes."
        }
        if lines.contains(where: { $0.hasPrefix("Finished `release`") }) {
            fraction = 0.93
            phase = "Finishing source build"
            detail = "Cargo finished; copying the final Apple Silicon binary."
        }
        if let error = lines.reversed().first(where: {
            $0.hasPrefix("error:") || $0.contains(" panicked at ")
        }) {
            phase = "Compiler reported an error"
            detail = error
        }
        let step: NodeUpdateStep = reachedFinalNodeBuild ? .linkNode : .compileNode
        return NodeUpdateProgress(
            step: step,
            phase: phase,
            detail: detail,
            fraction: fraction,
            startedAt: startedAt,
            isEstimate: true,
            logURL: logURL
        )
    }

}
