import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func branchCacheURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("BranchCache.git", isDirectory: true)
    }

    nonisolated static func newSourceBuildWorkspace(prefix: String) throws -> URL {
        // Some upstream native build scripts reject any prefix containing spaces.
        // The final activation bundle remains in Application Support; only compilation
        // occurs in this disposable, no-space temporary workspace.
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/QuilNode/BuildWorkspaces", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = root.appendingPathComponent("source-\(prefix)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated static func prepareSourceBuildSandbox(
        workspace: URL,
        repository: URL
    ) throws -> PreparedSourceBuildSandbox {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: SourceBuildSandbox.executable) else {
            throw UpdateCenterError.sourceSandboxUnavailable
        }
        let operatorHome = fm.homeDirectoryForCurrentUser
        let cargoExecutable = operatorHome.appendingPathComponent(".cargo/bin/cargo").path
        let rustupHome = operatorHome.appendingPathComponent(".rustup", isDirectory: true)
        let cargoBin = operatorHome.appendingPathComponent(".cargo/bin", isDirectory: true)
        let flint = operatorHome.appendingPathComponent(
            ".local/share/QuilNode/Toolchains/flint-3.6.0",
            isDirectory: true
        )
        guard fm.isExecutableFile(atPath: cargoExecutable),
            fm.fileExists(atPath: rustupHome.path),
            fm.fileExists(atPath: flint.path)
        else { throw UpdateCenterError.sourceToolMissing("isolated Rust/Flint toolchain") }

        let sandboxRoot = workspace.appendingPathComponent("sandbox", isDirectory: true)
        let cargoHome = sandboxRoot.appendingPathComponent("cargo-home", isDirectory: true)
        let isolatedHome = sandboxRoot.appendingPathComponent("home", isDirectory: true)
        let temporary = sandboxRoot.appendingPathComponent("tmp", isDirectory: true)
        for directory in [sandboxRoot, cargoHome, isolatedHome, temporary] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        let layout = SourceBuildSandbox.Layout(
            workspace: workspace,
            repository: repository,
            cargoHome: cargoHome,
            isolatedHome: isolatedHome,
            temporaryDirectory: temporary,
            rustupHome: rustupHome,
            cargoBin: cargoBin,
            flintDirectory: flint
        )
        let fetchProfile = sandboxRoot.appendingPathComponent("dependency-fetch.sb")
        let compileProfile = sandboxRoot.appendingPathComponent("compile-no-network.sb")
        try writePrivateBuildPolicy(
            try SourceBuildSandbox.profile(layout: layout, allowsNetwork: true),
            to: fetchProfile
        )
        try writePrivateBuildPolicy(
            try SourceBuildSandbox.profile(layout: layout, allowsNetwork: false),
            to: compileProfile
        )
        let environment = try SourceBuildSandbox.environment(layout: layout)

        // Fail closed before cloning or compiling if the host OS can no longer
        // apply this policy. Source updates are optional; silently building
        // unsandboxed is never an acceptable compatibility fallback.
        do {
            _ = try runChecked(
                SourceBuildSandbox.executable,
                try SourceBuildSandbox.arguments(
                    profileURL: compileProfile,
                    executable: "/usr/bin/true",
                    arguments: []
                ),
                currentDirectory: repository,
                environment: environment,
                timeout: 10
            )
        } catch {
            throw UpdateCenterError.sourceSandboxUnavailable
        }
        return PreparedSourceBuildSandbox(
            fetchProfile: fetchProfile,
            compileProfile: compileProfile,
            cargoExecutable: cargoExecutable,
            environment: environment
        )
    }

    nonisolated private static func writePrivateBuildPolicy(
        _ policy: String,
        to url: URL
    ) throws {
        try Data(policy.utf8).write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    nonisolated static func validateSourceBuildArtifact(
        _ url: URL,
        maximumBytes: UInt64
    ) throws {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFREG,
            metadata.st_nlink == 1,
            metadata.st_uid == getuid(),
            metadata.st_size > 0,
            UInt64(metadata.st_size) <= maximumBytes,
            metadata.st_mode & 0o111 != 0,
            metadata.st_mode & 0o022 == 0
        else { throw UpdateCenterError.sourceArtifactUnsafe(url.lastPathComponent) }
    }

    nonisolated static func cargoPackageCount(in repository: URL) -> Int {
        let lock = repository.appendingPathComponent("Cargo.lock")
        guard let data = try? BoundedLocalData.read(from: lock, maximumBytes: 8 * 1_024 * 1_024) else { return 800 }
        let text = String(decoding: data, as: UTF8.self)
        return max(text.components(separatedBy: "[[package]]").count - 1, 1)
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

    nonisolated static func cachedCompileUnits(in repository: URL, maximum: Int) -> Int {
        let fingerprints =
            repository
            .appendingPathComponent("target/aarch64-apple-darwin/release/.fingerprint", isDirectory: true)
        let count =
            (try? FileManager.default.contentsOfDirectory(
                at: fingerprints, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ).count) ?? 0
        return min(count, maximum)
    }

    nonisolated static func sourceBuildProgress(
        log: String,
        packageCount: Int,
        repository: URL,
        startedAt: Date,
        logURL: URL
    ) -> NodeUpdateProgress {
        let lines = log.split(whereSeparator: \.isNewline).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        let emittedCompiles = lines.filter { $0.hasPrefix("Compiling ") }.count
        let compiled = max(
            emittedCompiles,
            cachedCompileUnits(in: repository, maximum: packageCount)
        )
        let ratio = min(Double(compiled) / Double(max(packageCount, 1)), 1)
        var fraction = 0.16 + ratio * 0.72
        var phase = "Compiling node"
        var detail =
            lines.reversed().first(where: {
                $0.hasPrefix("Compiling ") || $0.hasPrefix("Finished ") || $0.hasPrefix("built ")
            }) ?? "Cargo is preparing dependencies"

        if lines.contains(where: { $0.hasPrefix("Compiling quil-node ") }) {
            fraction = max(fraction, 0.89)
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
        return NodeUpdateProgress(
            step: phase == "Linking optimized node" ? .linkNode : .compileNode,
            phase: phase,
            detail: detail,
            fraction: fraction,
            startedAt: startedAt,
            completedUnits: compiled,
            totalUnits: packageCount,
            isEstimate: true,
            logURL: logURL
        )
    }

    /// Hydrates the large seniority input identified by the immutable commit's
    /// Git LFS pointer. GitHub's LFS batch endpoint can be quota-limited even
    /// while its immutable media endpoint remains available, so both official
    /// transports are tried. The object is accepted only when its size and
    /// SHA-256 match the pointer committed by upstream.
    nonisolated static func prepareSeniorityDataset(in repository: URL) throws -> GitLFSPointer {
        let relativePath = "node/execution/intrinsics/global/compat/mainnet_244200_seniority.json"
        let destination = repository.appendingPathComponent(relativePath)
        let pointerText = try runChecked(
            gitExecutable, ["-C", repository.path, "show", "HEAD:\(relativePath)"], timeout: 30
        )
        guard let pointer = GitLFSPointerParser.parse(pointerText), pointer.size <= 600_000_000 else {
            throw UpdateCenterError.seniorityDatasetUnavailable
        }

        if !isLFSPointer(destination),
            (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) == pointer.size,
            sha256(of: destination) == pointer.oid
        {
            return pointer
        }

        if isLFSPointer(destination) {
            _ = try? runChecked(
                gitExecutable,
                ["-C", repository.path, "lfs", "pull", "--include=\(relativePath)", "--exclude="],
                timeout: 15 * 60
            )
        }
        if !isLFSPointer(destination),
            (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) == pointer.size,
            sha256(of: destination) == pointer.oid
        {
            return pointer
        }

        let commit = try runChecked(
            gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"], timeout: 30
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard commit.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil,
            let mediaURL = URL(
                string:
                    "https://media.githubusercontent.com/media/QuilibriumNetwork/monorepo/\(commit)/\(relativePath)"
            )
        else { throw UpdateCenterError.seniorityDatasetUnavailable }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".quilnode-lfs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try downloadGitHubMediaSynchronously(
            mediaURL, to: temporary, maximumBytes: 600_000_000
        )
        guard (try? temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize) == pointer.size,
            sha256(of: temporary) == pointer.oid
        else { throw UpdateCenterError.seniorityDatasetUnavailable }
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        return pointer
    }

    /// Uses Git's filtered-content comparison rather than porcelain status or
    /// `diff-index`'s stat-only fast path. A correctly hydrated LFS file is much
    /// larger than its index pointer and remains stat-dirty, while `git diff
    /// HEAD` runs the LFS clean filter and proves the content maps byte-for-byte
    /// to the immutable pointer. Staged and ordinary tracked edits still fail.
    nonisolated static func verifyPinnedCheckoutIsUnmodified(_ repository: URL) throws {
        do {
            _ = try runChecked(
                gitExecutable,
                ["-C", repository.path, "diff", "--quiet", "--exit-code", "HEAD", "--"],
                timeout: 60
            )
        } catch {
            throw UpdateCenterError.sourceCheckoutModified
        }
    }

    nonisolated static func isLFSPointer(_ url: URL) -> Bool {
        guard let data = try? BoundedLocalData.read(from: url, maximumBytes: 1_024) else { return true }
        return String(decoding: data, as: UTF8.self)
            .hasPrefix("version https://git-lfs.github.com/spec/v1")
    }

}
