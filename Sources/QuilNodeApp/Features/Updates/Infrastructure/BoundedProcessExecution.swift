import AppKit
import CryptoKit
import Darwin
import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    /// Apple Git has occasionally aborted `pack-objects` while negotiating a
    /// filtered shallow fetch. Retry the immutable fetch, then progressively
    /// relax only the object filter. Ref targets, depth, origin, and commit
    /// selection never change, so a transient transport failure cannot select
    /// a different update candidate.
    nonisolated static func runGitFetch(
        repository: URL,
        arguments: [String],
        timeout: TimeInterval
    ) throws {
        var variants = [arguments]
        if arguments.contains("--filter=tree:0") {
            variants.append(arguments.map { $0 == "--filter=tree:0" ? "--filter=blob:none" : $0 })
        }
        let unfiltered = arguments.filter { !$0.hasPrefix("--filter=") }
        if !variants.contains(unfiltered) { variants.append(unfiltered) }

        var lastError: Error = UpdateCenterError.commandFailed("Git fetch failed.")
        let deadline = Date().addingTimeInterval(timeout)
        for (index, variant) in variants.enumerated() {
            do {
                try Task.checkCancellation()
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else {
                    throw UpdateCenterError.commandTimedOut("git fetch", timeout)
                }
                try runChecked(
                    gitExecutable,
                    ["-C", repository.path, "-c", "protocol.version=2", "fetch", "-q"] + variant,
                    timeout: remaining
                )
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if index + 1 < variants.count { Thread.sleep(forTimeInterval: 0.35) }
            }
        }
        throw lastError
    }

    @discardableResult
    nonisolated static func runChecked(
        _ executable: String,
        _ arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60,
        logURL: URL? = nil,
        logProgress: (@Sendable (String) -> Void)? = nil,
        honorsCancellation: Bool = true,
        maximumOutputBytes: Int? = nil
    ) throws -> String {
        let process = Process()
        let maximumCaptureBytes: off_t = off_t(
            maximumOutputBytes
                ?? (logURL == nil ? 8 * 1_024 * 1_024 : 128 * 1_024 * 1_024))
        guard maximumCaptureBytes > 0 else {
            throw UpdateCenterError.commandFailed("Invalid command-output limit.")
        }
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        if let environment {
            process.environment = environment
        } else if URL(fileURLWithPath: executable).lastPathComponent == "git" {
            process.environment = sourceControlEnvironment()
        } else {
            process.environment = [
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": "/var/empty",
                "LANG": "C.UTF-8",
                "LC_ALL": "C.UTF-8",
            ]
        }
        let fm = FileManager.default
        let temporaryCapture =
            logURL == nil
            ? fm.temporaryDirectory.appendingPathComponent("quilnode-command-\(UUID().uuidString).log")
            : nil
        let captureURL = logURL ?? temporaryCapture!
        defer {
            if let temporaryCapture { try? fm.removeItem(at: temporaryCapture) }
        }
        let captureDescriptor = try openPrivateCaptureFile(captureURL)
        let logHandle = FileHandle(fileDescriptor: captureDescriptor, closeOnDealloc: true)
        let outputPump = BoundedProcessOutputPump(
            destinationDescriptor: captureDescriptor,
            maximumBytes: Int(maximumCaptureBytes)
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
        var nextProgressRead = Date()
        var wasCancelled = false
        var exceededOutputLimit = false
        while process.isRunning && Date() < deadline {
            if honorsCancellation && Task.isCancelled {
                wasCancelled = true
                break
            }
            if outputPump.exceededLimit || outputPump.failedWriting {
                exceededOutputLimit = true
                break
            }
            if let logURL, let logProgress, Date() >= nextProgressRead {
                try? logHandle.synchronize()
                if let text = readFileTail(logURL, maximumBytes: 2 * 1_024 * 1_024) {
                    logProgress(text)
                }
                nextProgressRead = Date().addingTimeInterval(1)
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        let didTimeOut = process.isRunning && !wasCancelled && !exceededOutputLimit
        if process.isRunning {
            terminateProcessTree(rootPID: process.processIdentifier, signal: SIGTERM)
            let terminationDeadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < terminationDeadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                terminateProcessTree(rootPID: process.processIdentifier, signal: SIGKILL)
            }
        }
        process.waitUntilExit()
        let drained = outputPump.waitUntilDrained()
        var finalMetadata = stat()
        let finalSize =
            fstat(logHandle.fileDescriptor, &finalMetadata) == 0
            ? finalMetadata.st_size : 0
        exceededOutputLimit =
            exceededOutputLimit
            || outputPump.exceededLimit
            || outputPump.failedWriting
            || !drained
            || finalSize > maximumCaptureBytes
        try? logHandle.close()
        let output = readFileTail(captureURL, maximumBytes: 2 * 1_024 * 1_024) ?? ""
        if logURL != nil { logProgress?(output) }
        if wasCancelled { throw CancellationError() }
        if exceededOutputLimit {
            throw UpdateCenterError.commandFailed(
                "\(URL(fileURLWithPath: executable).lastPathComponent) exceeded the secure build-output limit. The process tree was stopped."
            )
        }
        if didTimeOut { throw UpdateCenterError.commandTimedOut(executable, timeout) }
        guard process.terminationStatus == 0 else {
            throw UpdateCenterError.commandFailed(friendlyCommandFailure(output, fallback: executable))
        }
        return output
    }

    nonisolated static func readFileTail(_ url: URL, maximumBytes: UInt64) -> String? {
        guard maximumBytes > 0, maximumBytes <= UInt64(Int.max),
            let data = try? BoundedLocalData.readTail(
                from: url,
                maximumFileBytes: 128 * 1_024 * 1_024,
                maximumTailBytes: Int(maximumBytes)
            )
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Opens a compiler log without following a replacement link and validates
    /// the already-open descriptor before truncating anything. Build output is
    /// user-owned, but it must never become an arbitrary-file overwrite
    /// primitive if another local process tampers with a staging directory.
    nonisolated private static func openPrivateCaptureFile(_ url: URL) throws -> Int32 {
        do {
            return try PrivateLocalFileSystem.openCaptureFile(at: url)
        } catch {
            throw UpdateCenterError.commandFailed("The build log failed its ownership or file-type check.")
        }
    }

    nonisolated private static func terminateProcessTree(rootPID: pid_t, signal: Int32) {
        for child in childProcessIDs(of: rootPID) {
            terminateProcessTree(rootPID: child, signal: signal)
        }
        _ = Darwin.kill(rootPID, signal)
    }

    nonisolated private static func childProcessIDs(of parentPID: pid_t) -> [pid_t] {
        var children = [pid_t](repeating: 0, count: 512)
        let byteCount = children.withUnsafeMutableBytes { buffer in
            proc_listchildpids(parentPID, buffer.baseAddress, Int32(buffer.count))
        }
        guard byteCount > 0 else { return [] }
        return Array(children.prefix(Int(byteCount) / MemoryLayout<pid_t>.size))
            .filter { $0 > 0 }
    }

    nonisolated static func friendlyCommandFailure(_ output: String, fallback: String) -> String {
        let normalized = output.replacingOccurrences(of: "\\n", with: "\n")
        let lines = normalized.split(whereSeparator: \.isNewline).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }

        if let line = lines.reversed().first(where: {
            $0.localizedCaseInsensitiveContains("pack-objects")
                || $0.localizedCaseInsensitiveContains("fetch-pack")
        }) {
            return "Official repository refresh failed after safe retries: \(line)"
        }

        if let line = lines.reversed().first(where: { $0.contains("protoc failed:") }),
            let range = line.range(of: "protoc failed:")
        {
            return "Build failed: \(line[range.lowerBound...]). Full compiler output is available in the build log."
        }
        if let line = lines.reversed().first(where: { $0.hasPrefix("configure: error:") }) {
            return "Build failed: \(line). Full compiler output is available in the build log."
        }
        let important = lines.filter {
            $0.hasPrefix("error:") || $0.hasPrefix("Error:") || $0.contains("panicked at")
        }
        if !important.isEmpty {
            return (important.suffix(3) + ["Full compiler output is available in the build log."])
                .joined(separator: "\n")
        }
        let tail = lines.suffix(8).joined(separator: "\n")
        return tail.isEmpty ? fallback : String(tail.suffix(1_500))
    }
}
