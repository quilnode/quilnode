import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func runQClientBalance(timeout: TimeInterval) throws -> CommandResult {
        try runQClientRead(
            ["token", "--config", "/opt/quilibrium/node/.config", "balance"],
            timeout: timeout
        )
    }

    /// Runs only the two fixed, read-only node RPCs needed by the dashboard.
    /// qclient is privilege-dropped to the isolated node account, so the GUI
    /// process never gains access to identity material.
    static func runQClientProverTelemetry(timeout: TimeInterval) throws -> String {
        let status = try runQClientRead(["node", "prover", "status"], timeout: timeout)
        guard status.exitCode == 0, !status.timedOut else {
            throw HelperFailure.command("The local prover status read did not complete. \(status.output)")
        }
        let shardInfo = try runQClientRead(["node", "prover", "shardinfo"], timeout: timeout)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return String(
            decoding: try encoder.encode(
                QClientProverTelemetryPayload(
                    statusOutput: status.output,
                    shardInfoOutput: shardInfo.exitCode == 0 && !shardInfo.timedOut ? shardInfo.output : "",
                    observedAt: Date()
                )
            ),
            as: UTF8.self
        )
    }

    private static func runQClientRead(
        _ arguments: [String],
        timeout: TimeInterval
    ) throws -> CommandResult {
        let (qclient, qclientRecord) = try trustedQClient()
        let trustArguments = qclientRecord.trust == .officialSigned ? ["--signature-check=false"] : ["-y"]
        let runtimeHome = URL(
            fileURLWithPath: "/opt/quilibrium/node/.config/.qclient-runtime",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: runtimeHome, withIntermediateDirectories: true)
        guard chown(runtimeHome.path, serviceUID, serviceGID) == 0,
            chmod(runtimeHome.path, 0o700) == 0
        else { throw HelperFailure.service("unable to prepare the isolated qclient runtime") }

        var result = try runCommand(
            URL(fileURLWithPath: "/usr/bin/sudo"),
            [
                "-n", "-H", "-u", serviceUser, "--",
                "/usr/bin/env", "HOME=\(runtimeHome.path)",
                qclient.path,
            ] + trustArguments + arguments,
            timeout: timeout,
            currentDirectory: nodeDirectory
        )
        result.output = redactSensitiveCommandOutput(result.output)
        return result
    }

    static func runAsServiceUser(
        _ executable: URL,
        _ arguments: [String],
        timeout: TimeInterval,
        currentDirectory: URL = nodeDirectory
    ) throws -> String {
        // The helper is already root and every value below is fixed or validated.
        // sudo is used only as a privilege dropper; it cannot prompt or elevate.
        try run(
            URL(fileURLWithPath: "/usr/bin/sudo"),
            ["-n", "-H", "-u", serviceUser, "--", executable.path] + arguments,
            timeout: timeout,
            currentDirectory: currentDirectory
        )
    }

    /// Probes a newly installed executable without exposing the operator home,
    /// node identity, stores, or the network.
    static func runArtifactVersionProbe(
        _ executable: URL,
        _ arguments: [String],
        timeout: TimeInterval
    ) throws -> String {
        try runAsServiceUser(
            URL(fileURLWithPath: "/usr/bin/sandbox-exec"),
            ["-p", artifactVersionProbeProfile(executable), executable.path] + arguments,
            timeout: timeout,
            currentDirectory: URL(fileURLWithPath: "/var/empty", isDirectory: true)
        )
    }

    static func artifactVersionProbeProfile(_ executable: URL) -> String {
        let releaseDirectory = executable.deletingLastPathComponent().standardizedFileURL.path
        let privateAlias = releaseDirectory.hasPrefix("/var/") ? "/private" + releaseDirectory : releaseDirectory
        let readableRoots = [
            "/System", "/usr", "/bin", "/sbin", "/Library", "/dev",
            "/private/etc", "/private/var/db", "/var/empty",
            releaseDirectory, privateAlias,
        ]
        let rules = Array(Set(readableRoots)).sorted().map {
            "(allow file-read* (subpath \(sandboxLiteral($0))))"
        }.joined(separator: "\n")
        // exec traverses the versioned directory's ancestors before opening
        // the binary. Metadata-only access permits traversal without exposing
        // sibling releases, node configuration, or identity file contents.
        var ancestors = Set<String>()
        for root in readableRoots {
            var parent = URL(fileURLWithPath: root).deletingLastPathComponent()
            while parent.path != "/" && !parent.path.isEmpty {
                ancestors.insert(parent.path)
                parent.deleteLastPathComponent()
            }
        }
        let traversal = ancestors.sorted().map {
            "(allow file-read-metadata (literal \(sandboxLiteral($0))))"
        }.joined(separator: "\n")
        return """
            (version 1)
            (deny default)
            (allow process*)
            (allow signal (target self))
            (allow sysctl-read)
            (allow mach-lookup)
            (allow ipc-posix*)
            (deny network*)
            (allow file-read* (literal "/"))
            \(traversal)
            \(rules)
            """
    }

    static func qclientRuntimeVersion(_ output: String) -> String? {
        QClientVersion.parse(output)
    }

    private static func sandboxLiteral(_ value: String) -> String {
        "\""
            + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
