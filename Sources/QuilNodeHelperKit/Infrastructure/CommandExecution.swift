import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func nodeProcessIsRunning() -> Bool {
        guard let output = try? runLaunchctl(["print", serviceTarget]),
            let regex = try? NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)\s*$"#)
        else { return false }
        return regex.firstMatch(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        ) != nil
    }

    static func runNodeTool(_ arguments: [String], timeout: TimeInterval) throws -> String {
        let plist = try? readPlist()
        if plist?["UserName"] as? String == serviceUser {
            return try runAsServiceUser(nodeLink, arguments, timeout: timeout)
        }
        return try run(nodeLink, arguments, timeout: timeout)
    }

    static func runQClientBalance(timeout: TimeInterval) throws -> String {
        let (qclient, qclientRecord) = try trustedQClient()
        let trustArguments = qclientRecord.trust == .officialSigned ? ["--signature-check=false"] : ["-y"]

        let runtimeHome = URL(
            fileURLWithPath: "/opt/quilibrium/node/.config/.qclient-runtime",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: runtimeHome,
            withIntermediateDirectories: true
        )
        guard chown(runtimeHome.path, serviceUID, serviceGID) == 0,
            chmod(runtimeHome.path, 0o700) == 0
        else { throw HelperFailure.service("unable to prepare the isolated qclient runtime") }

        return try run(
            URL(fileURLWithPath: "/usr/bin/sudo"),
            [
                "-n", "-H", "-u", serviceUser, "--",
                "/usr/bin/env", "HOME=\(runtimeHome.path)",
                qclient.path,
            ] + trustArguments + [
                "token", "--config", "/opt/quilibrium/node/.config", "balance",
            ],
            timeout: timeout
        )
    }

    static func runAsServiceUser(
        _ executable: URL,
        _ arguments: [String],
        timeout: TimeInterval,
        currentDirectory: URL = nodeDirectory
    ) throws -> String {
        // The helper is already root and every value below is fixed or validated.
        // sudo is used only as a privilege dropper; it cannot prompt, elevate a caller,
        // interpret a shell command, or select an arbitrary executable.
        return try run(
            URL(fileURLWithPath: "/usr/bin/sudo"),
            ["-n", "-H", "-u", serviceUser, "--", executable.path] + arguments,
            timeout: timeout,
            currentDirectory: currentDirectory
        )
    }

    /// Probes a newly installed executable without exposing the operator home,
    /// node identity, stores, or the network. Publisher signatures establish
    /// provenance, not that invoking `version` is harmless.
    static func runArtifactVersionProbe(
        _ executable: URL,
        _ arguments: [String],
        timeout: TimeInterval
    ) throws -> String {
        let releaseDirectory = executable.deletingLastPathComponent().standardizedFileURL.path
        let privateAlias =
            releaseDirectory.hasPrefix("/var/")
            ? "/private" + releaseDirectory
            : releaseDirectory
        let readableRoots = [
            "/System", "/usr", "/bin", "/sbin", "/Library", "/dev",
            "/private/etc", "/private/var/db", "/var/empty",
            releaseDirectory, privateAlias,
        ]
        let rules = Array(Set(readableRoots)).sorted().map {
            "(allow file-read* (subpath \(sandboxLiteral($0))))"
        }.joined(separator: "\n")
        let profile = """
            (version 1)
            (deny default)
            (allow process*)
            (allow signal (target self))
            (allow sysctl-read)
            (allow mach-lookup)
            (allow ipc-posix*)
            (deny network*)
            (allow file-read* (literal "/"))
            \(rules)
            """
        return try runAsServiceUser(
            URL(fileURLWithPath: "/usr/bin/sandbox-exec"),
            ["-p", profile, executable.path] + arguments,
            timeout: timeout,
            currentDirectory: URL(fileURLWithPath: "/var/empty", isDirectory: true)
        )
    }

    static func qclientRuntimeVersion(_ output: String) -> String? {
        guard
            let expression = try? NSRegularExpression(
                pattern: #"(?m)^(?:qclient version:\s*)?([0-9]+\.[0-9]+\.[0-9]+-p[0-9]+)$"#
            )
        else { return nil }
        let fullRange = NSRange(output.startIndex..<output.endIndex, in: output)
        guard let match = expression.firstMatch(in: output, range: fullRange),
            let valueRange = Range(match.range(at: 1), in: output)
        else { return nil }
        return String(output[valueRange])
    }

    static func sandboxLiteral(_ value: String) -> String {
        "\""
            + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

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

    /// Hashes the file descriptor that was actually validated, rather than
    /// reopening a pathname after a separate check. `O_NOFOLLOW` closes the
    /// final-component symlink race and `O_NONBLOCK` prevents a substituted
    /// FIFO/device from hanging the privileged service. The second `fstat`
    /// rejects an in-place mutation that overlaps the read.
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
        // Keep the polling guard below for prompt termination, and also apply
        // a kernel-enforced file-size limit so a fast failing subprocess cannot
        // exhaust disk space between polls. Arguments remain positional; no
        // caller-controlled value is interpolated into the fixed shell text.
        let fileBlocks = max((Int(maximumCommandOutputBytes) + 511) / 512, 1)
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments =
            [
                "-c", "ulimit -f \"$1\" || exit 70; shift; exec \"$@\"",
                "quilnode-helper-command", String(fileBlocks), executable.path,
            ] + arguments
        process.currentDirectoryURL = currentDirectory
        process.environment = [
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
        ]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        var exceededOutputLimit = false
        while process.isRunning && Date() < deadline {
            var metadata = stat()
            if fstat(outputFD, &metadata) == 0,
                metadata.st_size > maximumCommandOutputBytes
            {
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
        try output.synchronize()
        var finalMetadata = stat()
        let finalSize = fstat(outputFD, &finalMetadata) == 0 ? finalMetadata.st_size : 0
        let outputLimitSignal =
            process.terminationReason == .uncaughtSignal
            && process.terminationStatus == SIGXFSZ
        try output.seek(toOffset: 0)
        let text = String(
            decoding: try output.read(upToCount: Int(maximumCommandOutputBytes) + 1) ?? Data(),
            as: UTF8.self
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !exceededOutputLimit,
            !outputLimitSignal,
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
