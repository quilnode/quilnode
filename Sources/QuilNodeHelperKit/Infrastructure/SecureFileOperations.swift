import CryptoKit
import Darwin
import Foundation

extension QuilNodeHelper {
    static func atomicSymlink(target: String, link: String) throws {
        try validateInstalledTarget(target, allowsSidecar: target.contains(".dgst"))
        let temporary = "\(link).quilnode-\(getpid()).tmp"
        unlink(temporary)
        guard symlink(target, temporary) == 0, rename(temporary, link) == 0 else {
            unlink(temporary)
            throw HelperFailure.command("Unable to switch the fixed node symlink: \(String(cString: strerror(errno)))")
        }
    }

    static func setRootPermissions(_ url: URL, mode: mode_t) throws {
        guard chown(url.path, 0, 0) == 0, chmod(url.path, mode) == 0 else {
            throw HelperFailure.command("Unable to secure \(url.lastPathComponent)")
        }
    }

    /// Hashes the file descriptor that was actually validated. `O_NOFOLLOW`
    /// closes the final-component symlink race; the second `fstat` rejects an
    /// in-place mutation that overlaps the read.
    static func sha256(_ url: URL) -> String? {
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_nlink == 1,
            before.st_size >= 0,
            before.st_size <= 1_073_741_824
        else { return nil }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        var hasher = SHA256()
        var bytesRead: off_t = 0
        do {
            while true {
                let data = try handle.read(upToCount: 4 * 1_024 * 1_024) ?? Data()
                if data.isEmpty { break }
                bytesRead += off_t(data.count)
                guard bytesRead <= before.st_size else { return nil }
                hasher.update(data: data)
            }
        } catch {
            return nil
        }

        var after = stat()
        guard fstat(descriptor, &after) == 0,
            bytesRead == before.st_size,
            before.st_dev == after.st_dev,
            before.st_ino == after.st_ino,
            before.st_mode == after.st_mode,
            before.st_nlink == after.st_nlink,
            before.st_uid == after.st_uid,
            before.st_gid == after.st_gid,
            before.st_size == after.st_size,
            before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
            before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
            before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
            before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
        else { return nil }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
