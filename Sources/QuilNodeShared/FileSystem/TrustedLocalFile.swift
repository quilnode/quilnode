import Darwin
import Foundation

/// Constrains a persisted pathname to a private, current-user-owned directory
/// tree before the application is allowed to open it.
///
/// A path stored in JSON is data, not an authority. This policy prevents a
/// corrupt or attacker-modified operation journal from turning a log or
/// manifest reader into an arbitrary local-file reader.
public enum TrustedLocalFile {
    public static func read(
        _ candidate: URL,
        inside root: URL,
        relativeDepth: Int,
        allowedFileNames: Set<String>? = nil,
        allowedPathExtensions: Set<String>? = nil,
        maximumBytes: Int,
        allowGrowth: Bool = false,
        ownerUID: uid_t = getuid()
    ) throws -> Data {
        guard maximumBytes > 0,
            let components = acceptedRelativeComponents(
                candidate,
                inside: root,
                relativeDepth: relativeDepth,
                allowedFileNames: allowedFileNames,
                allowedPathExtensions: allowedPathExtensions
            )
        else { throw CocoaError(.fileReadInvalidFileName) }

        var descriptor = open(
            root.standardizedFileURL.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
        )
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoPermission) }
        defer { close(descriptor) }

        try validatePrivateDirectory(descriptor, ownerUID: ownerUID)
        for component in components.dropLast() {
            let next = openat(
                descriptor,
                component,
                O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK
            )
            guard next >= 0 else { throw CocoaError(.fileReadNoPermission) }
            do {
                try validatePrivateDirectory(next, ownerUID: ownerUID)
            } catch {
                close(next)
                throw error
            }
            close(descriptor)
            descriptor = next
        }

        guard let fileName = components.last else { throw CocoaError(.fileReadInvalidFileName) }
        let file = openat(descriptor, fileName, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard file >= 0 else { throw CocoaError(.fileReadNoPermission) }
        defer { close(file) }

        var before = stat()
        guard fstat(file, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_uid == ownerUID,
            before.st_nlink == 1,
            before.st_mode & 0o077 == 0,
            before.st_size >= 0,
            before.st_size <= off_t(maximumBytes)
        else { throw CocoaError(.fileReadCorruptFile) }

        var data = Data(count: Int(before.st_size))
        let count = data.withUnsafeMutableBytes { bytes in
            guard let base = bytes.baseAddress else { return 0 }
            var total = 0
            while total < bytes.count {
                let result = Darwin.read(file, base.advanced(by: total), bytes.count - total)
                if result < 0, errno == EINTR { continue }
                guard result > 0 else { return -1 }
                total += result
            }
            return total
        }
        guard count == data.count else { throw CocoaError(.fileReadCorruptFile) }

        var after = stat()
        guard fstat(file, &after) == 0,
            before.st_dev == after.st_dev,
            before.st_ino == after.st_ino,
            before.st_mode == after.st_mode,
            before.st_nlink == after.st_nlink,
            before.st_uid == after.st_uid,
            before.st_gid == after.st_gid,
            (allowGrowth ? after.st_size >= before.st_size : after.st_size == before.st_size),
            (allowGrowth
                || (before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec
                    && before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
                    && before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec
                    && before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec))
        else { throw CocoaError(.fileReadCorruptFile) }
        return data
    }

    public static func validate(
        _ candidate: URL,
        inside root: URL,
        relativeDepth: Int,
        allowedFileNames: Set<String>? = nil,
        allowedPathExtensions: Set<String>? = nil,
        ownerUID: uid_t = getuid()
    ) -> URL? {
        guard
            let relativeComponents = acceptedRelativeComponents(
                candidate,
                inside: root,
                relativeDepth: relativeDepth,
                allowedFileNames: allowedFileNames,
                allowedPathExtensions: allowedPathExtensions
            )
        else { return nil }
        let trustedRoot = root.standardizedFileURL
        let file = candidate.standardizedFileURL

        var rootMetadata = stat()
        guard lstat(trustedRoot.path, &rootMetadata) == 0,
            (rootMetadata.st_mode & S_IFMT) == S_IFDIR,
            rootMetadata.st_uid == ownerUID,
            rootMetadata.st_mode & 0o077 == 0
        else { return nil }

        var current = trustedRoot
        for (index, component) in relativeComponents.enumerated() {
            current.appendPathComponent(component)
            var metadata = stat()
            guard lstat(current.path, &metadata) == 0,
                (metadata.st_mode & S_IFMT) != S_IFLNK
            else { return nil }

            let isFinal = index == relativeComponents.count - 1
            if isFinal {
                guard (metadata.st_mode & S_IFMT) == S_IFREG,
                    metadata.st_uid == ownerUID,
                    metadata.st_nlink == 1,
                    metadata.st_mode & 0o077 == 0
                else { return nil }
            } else {
                guard (metadata.st_mode & S_IFMT) == S_IFDIR,
                    metadata.st_uid == ownerUID,
                    metadata.st_mode & 0o077 == 0
                else { return nil }
            }
        }
        return file
    }

    private static func acceptedRelativeComponents(
        _ candidate: URL,
        inside root: URL,
        relativeDepth: Int,
        allowedFileNames: Set<String>?,
        allowedPathExtensions: Set<String>?
    ) -> [String]? {
        guard relativeDepth > 0 else { return nil }
        let trustedRoot = root.standardizedFileURL
        let file = candidate.standardizedFileURL
        let rootComponents = trustedRoot.pathComponents
        let fileComponents = file.pathComponents
        guard fileComponents.count == rootComponents.count + relativeDepth,
            Array(fileComponents.prefix(rootComponents.count)) == rootComponents,
            allowedFileNames?.contains(file.lastPathComponent) ?? true,
            allowedPathExtensions?.contains(file.pathExtension.lowercased()) ?? true
        else { return nil }
        return Array(fileComponents.dropFirst(rootComponents.count))
    }

    private static func validatePrivateDirectory(_ descriptor: Int32, ownerUID: uid_t) throws {
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFDIR,
            metadata.st_uid == ownerUID,
            metadata.st_mode & 0o077 == 0
        else { throw CocoaError(.fileReadNoPermission) }
    }
}
