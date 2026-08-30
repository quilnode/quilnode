import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func isLoaded() -> Bool {
        (try? runLaunchctl(["print", serviceTarget])) != nil
    }

    @discardableResult
    static func runLaunchctl(_ arguments: [String]) throws -> String {
        try run(launchctl, arguments, timeout: 20)
    }

    @discardableResult
    static func run(
        _ executable: URL,
        _ arguments: [String],
        timeout: TimeInterval,
        currentDirectory: URL = nodeDirectory
    ) throws -> String {
        let process = Process()
        var template = Array("/tmp/quilnode-helper-output.XXXXXX\0".utf8CString)
        let outputFD = template.withUnsafeMutableBufferPointer { buffer in
            mkstemp(buffer.baseAddress!)
        }
        guard outputFD >= 0 else {
            throw HelperFailure.command("Unable to create a private command-output file")
        }
        let outputPath = template.withUnsafeBufferPointer { buffer in
            String(cString: buffer.baseAddress!)
        }
        _ = fchmod(outputFD, 0o600)
        let output = FileHandle(fileDescriptor: outputFD, closeOnDealloc: true)
        defer {
            try? output.close()
            unlink(outputPath)
        }
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        ]
        let outputPump = BoundedProcessOutputPump(
            destinationDescriptor: outputFD,
            maximumBytes: Int(maximumCommandOutputBytes)
        )
        process.standardOutput = outputPump.pipe
        process.standardError = outputPump.pipe
        outputPump.start()
        do {
            try process.run()
        } catch {
            outputPump.cancelBeforeLaunch()
            _ = outputPump.waitUntilDrained()
            throw error
        }
        let deadline = Date().addingTimeInterval(timeout)
        var exceededOutputLimit = false
        while process.isRunning && Date() < deadline {
            if outputPump.exceededLimit || outputPump.failedWriting {
                exceededOutputLimit = true
                terminateProcessTree(rootPID: process.processIdentifier, signal: SIGTERM)
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            terminateProcessTree(rootPID: process.processIdentifier, signal: SIGTERM)
            let graceDeadline = Date().addingTimeInterval(1)
            while process.isRunning && Date() < graceDeadline { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning {
                terminateProcessTree(rootPID: process.processIdentifier, signal: SIGKILL)
            }
        }
        process.waitUntilExit()
        let drained = outputPump.waitUntilDrained()
        var finalMetadata = stat()
        let finalSize = fstat(outputFD, &finalMetadata) == 0 ? finalMetadata.st_size : 0
        try output.seek(toOffset: 0)
        let text = String(
            decoding: try output.read(upToCount: Int(maximumCommandOutputBytes) + 1) ?? Data(),
            as: UTF8.self
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !exceededOutputLimit,
            !outputPump.exceededLimit,
            !outputPump.failedWriting,
            drained,
            finalSize <= maximumCommandOutputBytes,
            text.utf8.count <= Int(maximumCommandOutputBytes)
        else {
            throw HelperFailure.command(
                "\(executable.lastPathComponent) exceeded the secure command-output limit"
            )
        }
        guard process.terminationStatus == 0 else {
            let safeText = redactSensitiveCommandOutput(text)
            throw HelperFailure.command(
                safeText.isEmpty ? "\(executable.lastPathComponent) failed" : safeText
            )
        }
        return text
    }

    static func redactSensitiveCommandOutput(_ text: String) -> String {
        let labels = ["peerPrivKey", "encryptionKey", "privateKey", "secretKey"]
        return labels.reduce(text) { current, label in
            current.replacingOccurrences(
                of: "(?im)(\\b\(label)\\s*[:=]\\s*)[^\\s,}]+",
                with: "$1<redacted>",
                options: .regularExpression
            )
        }
    }

    /// `Process.terminate()` only signals the direct sudo wrapper. If its
    /// dropped-privilege child is blocked in a node probe, that child becomes
    /// orphaned and can retain store/network resources indefinitely. Walk the
    /// fixed process tree and terminate descendants before their parent.
    static func terminateProcessTree(rootPID: pid_t, signal: Int32) {
        for child in childProcessIDs(of: rootPID) {
            terminateProcessTree(rootPID: child, signal: signal)
        }
        _ = Darwin.kill(rootPID, signal)
    }

    static func childProcessIDs(of parentPID: pid_t) -> [pid_t] {
        let capacity = 256
        var children = [pid_t](repeating: 0, count: capacity)
        let byteCount = children.withUnsafeMutableBytes { buffer in
            proc_listchildpids(parentPID, buffer.baseAddress, Int32(buffer.count))
        }
        guard byteCount > 0 else { return [] }
        return Array(children.prefix(Int(byteCount) / MemoryLayout<pid_t>.size)).filter { $0 > 0 }
    }
}
