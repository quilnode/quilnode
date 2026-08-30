import Darwin
import Foundation

public struct BoundedCommandResult: Sendable {
    public var output: String
    public var exitCode: Int32
    public var timedOut: Bool
    public var exceededOutputLimit: Bool

    public init(
        output: String,
        exitCode: Int32,
        timedOut: Bool = false,
        exceededOutputLimit: Bool = false
    ) {
        self.output = output
        self.exitCode = exitCode
        self.timedOut = timedOut
        self.exceededOutputLimit = exceededOutputLimit
    }
}

/// Executes fixed local tools without pipe backpressure, inherited secrets, or
/// unbounded output. Callers still own argument/path validation; this primitive
/// owns resource limits and complete process-tree cleanup.
public enum BoundedCommandRunner {
    public static func run(
        executable: String,
        arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval,
        maximumOutputBytes: Int = 1_048_576
    ) -> BoundedCommandResult {
        guard executable.hasPrefix("/"), maximumOutputBytes > 0 else {
            return .init(output: "Invalid bounded command request.", exitCode: 64)
        }
        var template = Array("/tmp/quilnode-command-output.XXXXXX\0".utf8CString)
        let descriptor = template.withUnsafeMutableBufferPointer { buffer in
            mkstemp(buffer.baseAddress!)
        }
        guard descriptor >= 0 else {
            return .init(output: "Unable to create private command output.", exitCode: 1)
        }
        let outputPath = template.withUnsafeBufferPointer { buffer in
            String(cString: buffer.baseAddress!)
        }
        _ = fchmod(descriptor, 0o600)
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer {
            try? handle.close()
            unlink(outputPath)
        }

        let process = Process()
        // Polling catches long-running producers; RLIMIT_FSIZE also prevents a
        // short-lived command from filling the disk before the next poll.
        let fileBlocks = max((maximumOutputBytes + 511) / 512, 1)
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments =
            [
                "-c", "ulimit -f \"$1\" || exit 70; shift; exec \"$@\"",
                "quilnode-bounded-command", String(fileBlocks), executable,
            ] + arguments
        process.currentDirectoryURL = currentDirectory
        process.environment =
            environment ?? [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "LANG": "C.UTF-8",
                "LC_ALL": "C.UTF-8",
            ]
        process.standardOutput = handle
        process.standardError = handle
        do {
            try process.run()
        } catch {
            return .init(output: error.localizedDescription, exitCode: -1)
        }

        let deadline = Date().addingTimeInterval(timeout)
        var exceeded = false
        while process.isRunning && Date() < deadline {
            var metadata = stat()
            if fstat(descriptor, &metadata) == 0,
                metadata.st_size > off_t(maximumOutputBytes)
            {
                exceeded = true
                break
            }
            Thread.sleep(forTimeInterval: 0.04)
        }
        let timedOut = process.isRunning && !exceeded
        if process.isRunning {
            terminateProcessTree(process.processIdentifier, signal: SIGTERM)
            let grace = Date().addingTimeInterval(1)
            while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.04) }
            if process.isRunning { terminateProcessTree(process.processIdentifier, signal: SIGKILL) }
        }
        process.waitUntilExit()
        try? handle.synchronize()
        var finalMetadata = stat()
        let finalSize = fstat(descriptor, &finalMetadata) == 0 ? finalMetadata.st_size : 0
        let outputLimitSignal =
            process.terminationReason == .uncaughtSignal
            && process.terminationStatus == SIGXFSZ
        let outputExceeded =
            exceeded
            || finalSize > off_t(maximumOutputBytes)
            || outputLimitSignal
        try? handle.seek(toOffset: 0)
        let data = (try? handle.read(upToCount: maximumOutputBytes + 1)) ?? Data()
        let output: String
        if outputExceeded || data.count > maximumOutputBytes {
            output = "Command exceeded the secure output limit."
        } else if timedOut {
            output = "Command timed out."
        } else {
            output = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return .init(
            output: output,
            exitCode: outputExceeded ? 75 : (timedOut ? 124 : process.terminationStatus),
            timedOut: timedOut,
            exceededOutputLimit: outputExceeded
        )
    }

    private static func terminateProcessTree(_ pid: pid_t, signal: Int32) {
        for child in childProcessIDs(pid) { terminateProcessTree(child, signal: signal) }
        _ = Darwin.kill(pid, signal)
    }

    private static func childProcessIDs(_ parentPID: pid_t) -> [pid_t] {
        var children = [pid_t](repeating: 0, count: 256)
        let byteCount = children.withUnsafeMutableBytes { buffer in
            proc_listchildpids(parentPID, buffer.baseAddress, Int32(buffer.count))
        }
        guard byteCount > 0 else { return [] }
        return Array(children.prefix(Int(byteCount) / MemoryLayout<pid_t>.size)).filter { $0 > 0 }
    }
}
