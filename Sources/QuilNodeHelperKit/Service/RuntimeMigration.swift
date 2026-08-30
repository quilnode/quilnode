import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func createMigrationBackup() throws {
        let fm = FileManager.default
        let backup = nodeDirectory.appendingPathComponent(".quilnode-migration-backup", isDirectory: true)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        guard chown(backup.path, 0, 0) == 0, chmod(backup.path, 0o700) == 0 else {
            throw HelperFailure.migration("unable to secure the migration backup")
        }
        let items: [(source: URL, destination: URL, maximumBytes: UInt64)] = [
            (URL(fileURLWithPath: plistPath), backup.appendingPathComponent("com.quilibrium.node.plist"), 1_000_000),
            (
                nodeDirectory.appendingPathComponent(".config/keys.yml"), backup.appendingPathComponent("keys.yml"),
                20_000_000
            ),
            (
                nodeDirectory.appendingPathComponent(".config/config.yml"), backup.appendingPathComponent("config.yml"),
                2_000_000
            ),
        ]
        var sourceHashes: [String] = []
        for item in items {
            let data = try readSecureRegularFile(item.source, maximumBytes: item.maximumBytes)
            sourceHashes.append("\(sha256(data))  \(item.source.lastPathComponent)")
            if !fm.fileExists(atPath: item.destination.path) {
                try writeRootFile(data, to: item.destination.path, mode: 0o600)
            }
        }
        let hashes = sourceHashes.joined(separator: "\n") + "\n"
        try writeRootFile(Data(hashes.utf8), to: backup.appendingPathComponent("SHA256SUMS").path, mode: 0o600)
    }

    static func prepareRuntimeOwnership() throws {
        let fm = FileManager.default
        let config = nodeDirectory.appendingPathComponent(".config", isDirectory: true)
        guard fm.fileExists(atPath: config.path) else {
            throw HelperFailure.migration("the active node configuration directory is missing")
        }
        try recursivelySetOwner(config, uid: serviceUID, gid: serviceGID)
        for name in ["node.log", "node-error.log"] {
            let log = nodeDirectory.appendingPathComponent(name)
            if !fm.fileExists(atPath: log.path) {
                guard fm.createFile(atPath: log.path, contents: nil) else {
                    throw HelperFailure.migration("unable to create the node log")
                }
            }
            guard chown(log.path, serviceUID, serviceGID) == 0,
                chmod(log.path, 0o644) == 0
            else { throw HelperFailure.migration("unable to prepare node log permissions") }
        }
        guard chmod(config.path, 0o700) == 0,
            chmod(config.appendingPathComponent("keys.yml").path, 0o600) == 0,
            chmod(config.appendingPathComponent("config.yml").path, 0o600) == 0
        else { throw HelperFailure.migration("unable to restrict runtime data permissions") }
    }

    static func writeNodeServicePlist(signatureCheck: Bool) throws {
        let plist: [String: Any] = [
            "Label": "com.quilibrium.node",
            "ProgramArguments": ["/opt/quilibrium/node/quilibrium-node"],
            "WorkingDirectory": "/opt/quilibrium/node",
            "UserName": serviceUser,
            "GroupName": serviceGroup,
            "RunAtLoad": true,
            "KeepAlive": true,
            "ProcessType": "Background",
            "EnvironmentVariables": [
                "QUILIBRIUM_SIGNATURE_CHECK": signatureCheck ? "true" : "false",
                "HOME": "/var/empty",
            ],
            "SoftResourceLimits": ["NumberOfFiles": 524_288],
            "HardResourceLimits": ["NumberOfFiles": 524_288],
            "StandardOutPath": "/opt/quilibrium/node/node.log",
            "StandardErrorPath": "/opt/quilibrium/node/node-error.log",
        ]
        try writeRootPlist(plist, to: plistPath)
        try validateLaunchDaemonPlist()
    }

    static func bootstrapOperatorService() throws {
        _ = try? runLaunchctl(["bootout", "system", operatorPlist])
        // Do not mistake the previous daemon's socket for readiness of the
        // replacement binary during a passwordless-service upgrade.
        unlink(operatorSocket)
        try runLaunchctl(["bootstrap", "system", operatorPlist])
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: operatorSocket) { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        let launchState = (try? runLaunchctl(["print", operatorTarget])) ?? "launchd has no service record"
        let diagnostic =
            launchState
            .split(separator: "\n")
            .filter { line in
                let text = line.lowercased()
                return text.contains("state =") || text.contains("pid =") || text.contains("last exit")
                    || text.contains("reason") || text.contains("error")
            }
            .prefix(8)
            .joined(separator: "; ")
        throw HelperFailure.migration(
            "the passwordless service did not create its authenticated socket (\(diagnostic))"
        )
    }

    static func rollbackRuntimeMigration(controllerUID: UInt32) throws {
        let fm = FileManager.default
        _ = try? runLaunchctl(["bootout", "system", plistPath])
        let backup = nodeDirectory.appendingPathComponent(".quilnode-migration-backup", isDirectory: true)
        let originalPlist = backup.appendingPathComponent("com.quilibrium.node.plist")
        guard fm.fileExists(atPath: originalPlist.path) else {
            throw HelperFailure.migration("the original LaunchDaemon backup is unavailable")
        }
        try writeRootFile(
            readSecureRegularFile(originalPlist, maximumBytes: 1_000_000, requiredOwner: 0),
            to: plistPath,
            mode: 0o644
        )
        let config = nodeDirectory.appendingPathComponent(".config", isDirectory: true)
        try recursivelySetOwner(config, uid: 0, gid: 0)
        _ = chmod(config.path, 0o755)
        for name in ["keys.yml", "config.yml"] {
            let file = config.appendingPathComponent(name)
            _ = chown(file.path, uid_t(controllerUID), 20)
            _ = chmod(file.path, 0o600)
        }
        try runLaunchctl(["bootstrap", "system", plistPath])
    }

    static func removeOperatorService() throws {
        _ = try? runLaunchctl(["bootout", "system", operatorPlist])
        unlink(operatorSocket)
        try? FileManager.default.removeItem(atPath: operatorPlist)
        try? FileManager.default.removeItem(atPath: operatorBinary)
        try? FileManager.default.removeItem(atPath: operatorConfig)
        try? FileManager.default.removeItem(atPath: operatorVerifier)
    }

    static func ensureFileDescriptorLimits() throws {
        let sysctl = URL(fileURLWithPath: "/usr/sbin/sysctl")
        _ = try run(sysctl, ["-w", "kern.maxfiles=524288"], timeout: 15)
        _ = try run(sysctl, ["-w", "kern.maxfilesperproc=524288"], timeout: 15)

        let url = URL(fileURLWithPath: "/etc/sysctl.conf")
        let original: String
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try readSecureRegularFile(
                url,
                maximumBytes: 1_000_000,
                requiredOwner: 0
            )
            guard let decoded = String(data: data, encoding: .utf8) else {
                throw HelperFailure.command("The existing sysctl configuration is not UTF-8.")
            }
            original = decoded
        } else {
            original = ""
        }
        var retained = original.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            .filter {
                let value = $0.trimmingCharacters(in: .whitespaces)
                return !value.hasPrefix("kern.maxfiles=") && !value.hasPrefix("kern.maxfilesperproc=")
            }
        while retained.last?.isEmpty == true { retained.removeLast() }
        retained.append(contentsOf: [
            "# Managed by QuilNode for the Quilibrium launch daemon",
            "kern.maxfiles=524288",
            "kern.maxfilesperproc=524288",
        ])
        let updated = retained.joined(separator: "\n") + "\n"
        guard updated != original else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            let backup = "/etc/sysctl.conf.quilnode-backup"
            if !FileManager.default.fileExists(atPath: backup) {
                try writeRootFile(Data(original.utf8), to: backup, mode: 0o600)
            }
        }
        try writeRootFile(Data(updated.utf8), to: url.path, mode: 0o644)
    }
}
