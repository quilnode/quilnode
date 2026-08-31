import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static let mutationLockTimeout: TimeInterval = 30

    static func withMutationLock<T>(
        timeout: TimeInterval = mutationLockTimeout,
        _ operation: () throws -> T
    ) throws -> T {
        let deadline = monotonicDeadline(after: timeout)
        guard acquireInProcessMutationLock(until: deadline) else {
            throw HelperFailure.service(
                "another privileged operation is still running; try again after it completes"
            )
        }
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
            metadata.st_mode & 0o077 == 0
        else {
            throw HelperFailure.service("the privileged mutation lock is unsafe")
        }
        guard try acquireFileMutationLock(descriptor, until: deadline) else {
            throw HelperFailure.service(
                "another privileged operation is still running; try again after it completes"
            )
        }
        defer { _ = flock(descriptor, LOCK_UN) }
        return try operation()
    }

    static func monotonicDeadline(after timeout: TimeInterval) -> UInt64 {
        let nanoseconds = UInt64(max(timeout, 0) * 1_000_000_000)
        let now = DispatchTime.now().uptimeNanoseconds
        let (deadline, overflow) = now.addingReportingOverflow(nanoseconds)
        return overflow ? UInt64.max : deadline
    }

    static func acquireInProcessMutationLock(until deadline: UInt64) -> Bool {
        repeat {
            if mutationLock.try() { return true }
            if DispatchTime.now().uptimeNanoseconds >= deadline { return false }
            usleep(50_000)
        } while true
    }

    private static func acquireFileMutationLock(
        _ descriptor: Int32,
        until deadline: UInt64
    ) throws -> Bool {
        repeat {
            if flock(descriptor, LOCK_EX | LOCK_NB) == 0 { return true }
            let failure = errno
            if failure == EINTR { continue }
            guard failure == EWOULDBLOCK || failure == EAGAIN else {
                throw HelperFailure.service("unable to acquire the privileged mutation lock")
            }
            if DispatchTime.now().uptimeNanoseconds >= deadline { return false }
            usleep(50_000)
        } while true
    }

    // MARK: - macOS Application Firewall

    /// Returns the versioned binary behind the fixed node symlink. The helper
    /// never accepts a path from the GUI for firewall mutations.
}
