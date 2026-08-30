import Darwin
import Foundation

/// Reads application-owned state without following links or trusting a
/// path-level size check. This is not a key-file API; it protects local UI
/// caches from same-user replacement, FIFO blocking, and memory exhaustion.
public enum BoundedLocalData {
    public static func read(from url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0 else { throw CocoaError(.fileReadTooLarge) }
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoSuchFile) }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_nlink == 1,
            before.st_size > 0,
            before.st_size <= off_t(maximumBytes)
        else { throw CocoaError(.fileReadCorruptFile) }

        var result = Data()
        result.reserveCapacity(Int(before.st_size))
        var buffer = [UInt8](repeating: 0, count: min(64 * 1_024, maximumBytes))
        while result.count < Int(before.st_size) {
            let requested = min(buffer.count, Int(before.st_size) - result.count)
            let count = Darwin.read(descriptor, &buffer, requested)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw CocoaError(.fileReadCorruptFile) }
            result.append(buffer, count: count)
        }

        var after = stat()
        guard fstat(descriptor, &after) == 0,
            metadataIsUnchanged(before, after)
        else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }

    /// Reads only the tail of a potentially large application-owned text file.
    /// The descriptor is opened without following links and its complete
    /// security-relevant metadata is rechecked after the read.
    public static func readTail(
        from url: URL,
        maximumFileBytes: Int,
        maximumTailBytes: Int,
        allowGrowth: Bool = false
    ) throws -> Data {
        guard maximumFileBytes > 0, maximumTailBytes > 0 else {
            throw CocoaError(.fileReadTooLarge)
        }
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoSuchFile) }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_nlink == 1,
            before.st_size >= 0,
            before.st_size <= off_t(maximumFileBytes)
        else { throw CocoaError(.fileReadCorruptFile) }

        let byteCount = min(Int(before.st_size), maximumTailBytes)
        let offset = before.st_size - off_t(byteCount)
        guard lseek(descriptor, offset, SEEK_SET) == offset else {
            throw CocoaError(.fileReadUnknown)
        }

        var result = Data()
        result.reserveCapacity(byteCount)
        var buffer = [UInt8](repeating: 0, count: min(64 * 1_024, maximumTailBytes))
        while result.count < byteCount {
            let requested = min(buffer.count, byteCount - result.count)
            let count = Darwin.read(descriptor, &buffer, requested)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw CocoaError(.fileReadCorruptFile) }
            result.append(buffer, count: count)
        }

        var after = stat()
        guard fstat(descriptor, &after) == 0,
            (allowGrowth
                ? metadataIsCompatibleWithAppend(before, after)
                : metadataIsUnchanged(before, after))
        else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }

    /// Searches bounded chunks from the end of a growing log without ever
    /// resolving the path after open. Appends are tolerated, while inode,
    /// ownership, link-count, type, mode changes, and truncation are rejected.
    public static func firstMatchInReverseTail<Result>(
        from url: URL,
        maximumFileBytes: Int,
        maximumScanBytes: Int,
        chunkBytes: Int,
        overlapBytes: Int = 4_096,
        find: (Data) -> Result?
    ) throws -> Result? {
        guard maximumFileBytes > 0,
            maximumScanBytes > 0,
            chunkBytes > 0,
            overlapBytes >= 0,
            overlapBytes < chunkBytes
        else { throw CocoaError(.fileReadTooLarge) }

        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
        guard descriptor >= 0 else { throw CocoaError(.fileReadNoSuchFile) }
        defer { close(descriptor) }

        var before = stat()
        guard fstat(descriptor, &before) == 0,
            (before.st_mode & S_IFMT) == S_IFREG,
            before.st_nlink == 1,
            before.st_size >= 0,
            before.st_size <= off_t(maximumFileBytes)
        else { throw CocoaError(.fileReadCorruptFile) }

        let capturedEnd = Int(before.st_size)
        let lowerBound = max(0, capturedEnd - maximumScanBytes)
        var end = capturedEnd
        var result: Result?

        while end > lowerBound {
            let start = max(lowerBound, end - chunkBytes)
            let requested = end - start
            var data = Data(count: requested)
            let count = data.withUnsafeMutableBytes { bytes in
                pread(descriptor, bytes.baseAddress, requested, off_t(start))
            }
            guard count == requested else { throw CocoaError(.fileReadCorruptFile) }
            if let match = find(data) {
                result = match
                break
            }
            if start == lowerBound { break }
            end = min(capturedEnd, start + overlapBytes)
        }

        var after = stat()
        guard fstat(descriptor, &after) == 0,
            metadataIsCompatibleWithAppend(before, after)
        else { throw CocoaError(.fileReadCorruptFile) }
        return result
    }

    private static func metadataIsUnchanged(_ before: stat, _ after: stat) -> Bool {
        before.st_dev == after.st_dev
            && before.st_ino == after.st_ino
            && before.st_mode == after.st_mode
            && before.st_nlink == after.st_nlink
            && before.st_uid == after.st_uid
            && before.st_gid == after.st_gid
            && before.st_size == after.st_size
            && before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec
            && before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
            && before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec
            && before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
    }

    private static func metadataIsCompatibleWithAppend(_ before: stat, _ after: stat) -> Bool {
        before.st_dev == after.st_dev
            && before.st_ino == after.st_ino
            && before.st_mode == after.st_mode
            && before.st_nlink == after.st_nlink
            && before.st_uid == after.st_uid
            && before.st_gid == after.st_gid
            && after.st_size >= before.st_size
    }
}
