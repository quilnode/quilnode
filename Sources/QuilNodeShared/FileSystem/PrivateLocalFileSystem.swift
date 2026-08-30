import Darwin
import Foundation

/// Creates private application directories and atomically replaces state files
/// without following a destination link or reopening a pathname after checks.
public enum PrivateLocalFileSystem {
    /// Opens a private regular capture file relative to its already-validated
    /// directory. The caller owns the returned descriptor.
    public static func openCaptureFile(
        at url: URL,
        mode: mode_t = 0o600,
        ownerUID: uid_t = getuid()
    ) throws -> Int32 {
        guard mode & 0o077 == 0 else { throw CocoaError(.fileWriteNoPermission) }
        let location = url.standardizedFileURL
        let name = try finalComponent(of: location)
        let parent = try openPrivateDirectory(location.deletingLastPathComponent(), ownerUID: ownerUID)
        defer { close(parent) }

        let descriptor = openat(
            parent,
            name,
            O_WRONLY | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK,
            mode
        )
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFREG,
            metadata.st_uid == ownerUID,
            metadata.st_nlink == 1,
            fchmod(descriptor, mode) == 0,
            ftruncate(descriptor, 0) == 0,
            lseek(descriptor, 0, SEEK_SET) == 0
        else {
            close(descriptor)
            throw CocoaError(.fileWriteNoPermission)
        }
        return descriptor
    }

    public static func ensureDirectory(at url: URL, ownerUID: uid_t = getuid()) throws {
        let location = url.standardizedFileURL
        let name = try finalComponent(of: location)
        let parent = try openPrivateDirectory(location.deletingLastPathComponent(), ownerUID: ownerUID)
        defer { close(parent) }

        if mkdirat(parent, name, 0o700) != 0, errno != EEXIST {
            throw CocoaError(.fileWriteUnknown)
        }
        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteInvalidFileName) }
        defer { close(descriptor) }

        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFDIR,
            metadata.st_uid == ownerUID
        else { throw CocoaError(.fileWriteNoPermission) }
        guard fchmod(descriptor, 0o700) == 0,
            fstat(descriptor, &metadata) == 0,
            metadata.st_mode & 0o077 == 0
        else { throw CocoaError(.fileWriteNoPermission) }
    }

    public static func createExclusiveDirectory(at url: URL, ownerUID: uid_t = getuid()) throws {
        let location = url.standardizedFileURL
        let name = try finalComponent(of: location)
        let parent = try openPrivateDirectory(location.deletingLastPathComponent(), ownerUID: ownerUID)
        defer { close(parent) }
        guard mkdirat(parent, name, 0o700) == 0 else { throw CocoaError(.fileWriteFileExists) }

        let descriptor = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else {
            _ = unlinkat(parent, name, AT_REMOVEDIR)
            throw CocoaError(.fileWriteUnknown)
        }
        defer { close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFDIR,
            metadata.st_uid == ownerUID,
            metadata.st_mode & 0o077 == 0
        else {
            _ = unlinkat(parent, name, AT_REMOVEDIR)
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    public static func write(
        _ data: Data,
        atomicallyTo url: URL,
        mode: mode_t = 0o600,
        ownerUID: uid_t = getuid()
    ) throws {
        guard mode & 0o077 == 0 else { throw CocoaError(.fileWriteNoPermission) }
        let location = url.standardizedFileURL
        let destinationName = try finalComponent(of: location)
        let parent = try openPrivateDirectory(location.deletingLastPathComponent(), ownerUID: ownerUID)
        defer { close(parent) }

        let temporaryName = ".\(destinationName).\(UUID().uuidString).tmp"
        let descriptor = openat(
            parent,
            temporaryName,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK,
            mode
        )
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        var keepTemporary = true
        defer {
            close(descriptor)
            if keepTemporary { _ = unlinkat(parent, temporaryName, 0) }
        }

        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFREG,
            metadata.st_uid == ownerUID,
            metadata.st_nlink == 1,
            fchmod(descriptor, mode) == 0
        else { throw CocoaError(.fileWriteNoPermission) }

        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var written = 0
            while written < bytes.count {
                let count = Darwin.write(descriptor, base.advanced(by: written), bytes.count - written)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw CocoaError(.fileWriteUnknown) }
                written += count
            }
        }
        guard fsync(descriptor) == 0,
            renameat(parent, temporaryName, parent, destinationName) == 0
        else { throw CocoaError(.fileWriteUnknown) }
        keepTemporary = false
        _ = fsync(parent)
    }

    private static func openPrivateDirectory(_ url: URL, ownerUID: uid_t) throws -> Int32 {
        let descriptor = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFDIR,
            metadata.st_uid == ownerUID,
            metadata.st_mode & 0o022 == 0
        else {
            close(descriptor)
            throw CocoaError(.fileWriteNoPermission)
        }
        return descriptor
    }

    private static func finalComponent(of url: URL) throws -> String {
        let name = url.lastPathComponent
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return name
    }
}
