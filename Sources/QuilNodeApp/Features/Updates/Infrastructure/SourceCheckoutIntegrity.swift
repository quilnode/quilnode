import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    /// Hydrates the large seniority input identified by the immutable commit's
    /// Git LFS pointer. Both official transports are accepted, but the object
    /// must match the size and SHA-256 committed by upstream.
    nonisolated static func prepareSeniorityDataset(in repository: URL) throws -> GitLFSPointer {
        let relativePath = seniorityDatasetRelativePath
        let destination = repository.appendingPathComponent(relativePath)
        let pointerText = try runChecked(
            gitExecutable, ["-C", repository.path, "show", "HEAD:\(relativePath)"], timeout: 30
        )
        guard let pointer = GitLFSPointerParser.parse(pointerText), pointer.size <= 600_000_000 else {
            throw UpdateCenterError.seniorityDatasetUnavailable
        }

        if datasetMatches(destination, pointer: pointer) { return pointer }
        if isLFSPointer(destination) {
            _ = try? runChecked(
                gitExecutable,
                ["-C", repository.path, "lfs", "pull", "--include=\(relativePath)", "--exclude="],
                timeout: 15 * 60
            )
        }
        if datasetMatches(destination, pointer: pointer) { return pointer }

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
        try downloadGitHubMediaSynchronously(mediaURL, to: temporary, maximumBytes: 600_000_000)
        guard datasetMatches(temporary, pointer: pointer) else {
            throw UpdateCenterError.seniorityDatasetUnavailable
        }
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        return pointer
    }

    /// Proves that the immutable checkout has no staged changes and that its
    /// only working-tree difference is the verified seniority LFS object.
    nonisolated static func verifyPinnedCheckoutIsUnmodified(
        _ repository: URL,
        hydratedSeniorityDataset pointer: GitLFSPointer
    ) throws {
        do {
            _ = try runChecked(
                gitExecutable,
                [
                    "-C", repository.path, "diff", "--cached", "--quiet", "--exit-code",
                    "--no-ext-diff", "--no-textconv", "HEAD", "--",
                ],
                timeout: 60
            )
            let changedPaths = try runChecked(
                gitExecutable,
                [
                    "-C", repository.path, "diff", "--name-only", "--no-renames",
                    "--no-ext-diff", "--no-textconv", "-z", "--",
                ],
                timeout: 60
            ).split(separator: "\0").map(String.init)
            guard changedPaths == [seniorityDatasetRelativePath] else {
                throw UpdateCenterError.sourceCheckoutModified
            }
            let untrackedPaths = try runChecked(
                gitExecutable,
                ["-C", repository.path, "ls-files", "--others", "--exclude-standard", "-z"],
                timeout: 60
            )
            guard untrackedPaths.isEmpty else { throw UpdateCenterError.sourceCheckoutModified }

            let datasetURL = repository.appendingPathComponent(seniorityDatasetRelativePath)
            var metadata = stat()
            guard lstat(datasetURL.path, &metadata) == 0,
                metadata.st_mode & S_IFMT == S_IFREG,
                metadata.st_nlink == 1,
                metadata.st_uid == getuid(),
                datasetMatches(datasetURL, pointer: pointer)
            else { throw UpdateCenterError.sourceCheckoutModified }
        } catch {
            throw UpdateCenterError.sourceCheckoutModified
        }
    }

    nonisolated static func isLFSPointer(_ url: URL) -> Bool {
        guard let data = try? BoundedLocalData.read(from: url, maximumBytes: 1_024) else { return true }
        return String(decoding: data, as: UTF8.self)
            .hasPrefix("version https://git-lfs.github.com/spec/v1")
    }

    nonisolated private static func datasetMatches(_ url: URL, pointer: GitLFSPointer) -> Bool {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) == pointer.size
            && sha256(of: url) == pointer.oid
    }
}
