import Darwin
import Foundation

/// Drains a child process' stdout and stderr into a caller-owned file without
/// applying a process-wide file-size limit to the child itself.
///
/// A process-wide file-size resource limit is intentionally not used here:
/// resource limits are inherited by child processes and would also cap Git
/// packfiles, compiler outputs, and every other legitimate file the command
/// creates. The pipe provides backpressure while this pump enforces an exact
/// byte limit on output alone.
public final class BoundedProcessOutputPump: @unchecked Sendable {
    public let pipe = Pipe()

    private let destinationDescriptor: Int32
    private let maximumBytes: Int
    private let queue = DispatchQueue(label: "com.quilnode.process-output", qos: .utility)
    private let completion = DispatchGroup()
    private let lock = NSLock()

    private var capturedBytes = 0
    private var didExceedLimit = false
    private var didFailWriting = false
    private var started = false

    public init(destinationDescriptor: Int32, maximumBytes: Int) {
        precondition(destinationDescriptor >= 0)
        precondition(maximumBytes > 0)
        self.destinationDescriptor = destinationDescriptor
        self.maximumBytes = maximumBytes
    }

    public var exceededLimit: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didExceedLimit
    }

    public var failedWriting: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFailWriting
    }

    /// Start draining before launching the process so the child can never block
    /// on a full pipe while the parent is still configuring its timeout loop.
    public func start() {
        lock.lock()
        guard !started else {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        completion.enter()
        queue.async { [self] in
            defer {
                try? pipe.fileHandleForReading.close()
                completion.leave()
            }
            drain()
        }
    }

    /// Used only when `Process.run()` fails before Foundation transfers the
    /// pipe's write end to a launched child.
    public func cancelBeforeLaunch() {
        try? pipe.fileHandleForWriting.close()
        try? pipe.fileHandleForReading.close()
    }

    /// Wait for all bytes already written by the child to reach the bounded
    /// destination. A defensive timeout closes the read end rather than
    /// allowing shutdown to hang indefinitely.
    @discardableResult
    public func waitUntilDrained(timeout: TimeInterval = 5) -> Bool {
        if completion.wait(timeout: .now() + timeout) == .success { return true }
        try? pipe.fileHandleForReading.close()
        return completion.wait(timeout: .now() + 1) == .success
    }

    private func drain() {
        while true {
            let chunk: Data
            do {
                guard let next = try pipe.fileHandleForReading.read(upToCount: 64 * 1_024),
                    !next.isEmpty
                else { return }
                chunk = next
            } catch {
                return
            }

            let remaining: Int
            lock.lock()
            remaining = maximumBytes - capturedBytes
            lock.unlock()

            if chunk.count > remaining {
                if remaining > 0, !writeAll(chunk.prefix(remaining)) {
                    markWriteFailure()
                    return
                }
                lock.lock()
                capturedBytes = maximumBytes
                didExceedLimit = true
                lock.unlock()
                return
            }

            guard writeAll(chunk) else {
                markWriteFailure()
                return
            }
            lock.lock()
            capturedBytes += chunk.count
            lock.unlock()
        }
    }

    private func writeAll<D: DataProtocol>(_ data: D) -> Bool {
        let bytes = Data(data)
        return bytes.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return true }
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(
                    destinationDescriptor,
                    baseAddress.advanced(by: offset),
                    buffer.count - offset
                )
                if written < 0, errno == EINTR { continue }
                guard written > 0 else { return false }
                offset += written
            }
            return true
        }
    }

    private func markWriteFailure() {
        lock.lock()
        didFailWriting = true
        lock.unlock()
    }
}
