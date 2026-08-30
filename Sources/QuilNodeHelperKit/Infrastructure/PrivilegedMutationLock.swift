import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func withMutationLock<T>(_ operation: () throws -> T) throws -> T {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        let descriptor = open(
            mutationLockPath,
            O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
            mode_t(0o600)
        )
        guard descriptor >= 0 else {
            throw HelperFailure.service("unable to open the privileged mutation lock")
        }
        defer { close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
            (metadata.st_mode & S_IFMT) == S_IFREG,
            metadata.st_uid == 0,
            metadata.st_nlink == 1,
            metadata.st_mode & 0o077 == 0,
            flock(descriptor, LOCK_EX) == 0
        else {
            throw HelperFailure.service("the privileged mutation lock is unsafe")
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try operation()
    }

    // MARK: - macOS Application Firewall

    /// Returns the versioned binary behind the fixed node symlink. The helper
    /// never accepts a path from the GUI for firewall mutations.
}
