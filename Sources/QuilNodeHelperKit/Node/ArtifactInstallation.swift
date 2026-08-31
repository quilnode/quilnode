import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func validateRegularFile(_ url: URL, maximumBytes: UInt64) throws {
        var info = stat()
        guard lstat(url.path, &info) == 0,
            (info.st_mode & S_IFMT) == S_IFREG,
            info.st_nlink == 1,
            info.st_size > 0,
            UInt64(info.st_size) <= maximumBytes,
            info.st_mode & 0o022 == 0
        else { throw HelperFailure.unsafeStage("\(url.lastPathComponent) is not a safe regular file") }
    }

    static func validateRootOwnedExecutable(_ url: URL, maximumBytes: UInt64) throws {
        try validateRegularFile(url, maximumBytes: maximumBytes)
        var info = stat()
        guard lstat(url.path, &info) == 0,
            info.st_uid == 0,
            info.st_gid == 0,
            info.st_mode & 0o111 != 0
        else { throw HelperFailure.service("the privileged release verifier ownership or mode is unsafe") }
    }

    static func installFiles(_ manifest: ActivationManifest, stage: URL) throws -> URL {
        let fm = FileManager.default
        let source = stage.appendingPathComponent(manifest.binaryFileName)
        let destination = nodeDirectory.appendingPathComponent(manifest.binaryFileName)
        if fm.fileExists(atPath: destination.path) {
            guard sha256(destination) == manifest.sha256 else {
                throw HelperFailure.invalidManifest("a different installed file already uses this name")
            }
        } else {
            try fm.copyItem(at: source, to: destination)
        }
        try setRootPermissions(destination, mode: 0o755)
        guard sha256(destination) == manifest.sha256 else {
            try? fm.removeItem(at: destination)
            throw HelperFailure.invalidManifest("the installed binary SHA-256 changed during staging")
        }

        let sidecarNames =
            ["\(manifest.binaryFileName).dgst"]
            + manifest.signatureIndices.map { "\(manifest.binaryFileName).dgst.sig.\($0)" }
            + ["\(manifest.binaryFileName).BUILD-INFO.txt"]
        for name in sidecarNames {
            let staged = stage.appendingPathComponent(name)
            guard fm.fileExists(atPath: staged.path) else { continue }
            try validateRegularFile(staged, maximumBytes: 64_000)
            let installed = nodeDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: installed.path) {
                guard sha256(installed) == sha256(staged) else {
                    throw HelperFailure.invalidManifest("a different installed sidecar already uses \(name)")
                }
            } else {
                try fm.copyItem(at: staged, to: installed)
            }
            try setRootPermissions(installed, mode: 0o644)
        }
        return destination
    }

    /// Installs one node candidate without trusting the GUI's manifest or its
    /// earlier verification. Signed releases are verified twice: once while
    /// staged, then again from the root-owned installed copy. The second pass
    /// binds activation to the bytes that will actually execute and closes the
    /// validation-to-copy race inherent in a user-writable staging directory.
    static func installVerifiedNodeCandidate(
        _ manifest: ActivationManifest,
        stage: URL
    ) throws -> URL {
        if manifest.channel == "signed" {
            try verifySignedRelease(manifest, stage: stage)
        }
        let installed = try installFiles(manifest, stage: stage)
        if manifest.channel == "signed" {
            try verifySignedRelease(manifest, stage: nodeDirectory)
        }
        return installed
    }

    static func switchLinks(to binary: URL, manifest: ActivationManifest) throws {
        try atomicSymlink(target: binary.path, link: nodeLink.path)
        let digest = nodeDirectory.appendingPathComponent("\(manifest.binaryFileName).dgst")
        if FileManager.default.fileExists(atPath: digest.path) {
            try atomicSymlink(target: digest.path, link: "\(nodeLink.path).dgst")
        } else {
            unlink("\(nodeLink.path).dgst")
        }
        for index in 1...17 {
            let link = "\(nodeLink.path).dgst.sig.\(index)"
            if manifest.signatureIndices.contains(index) {
                let target = nodeDirectory.appendingPathComponent("\(manifest.binaryFileName).dgst.sig.\(index)").path
                try atomicSymlink(target: target, link: link)
            } else {
                unlink(link)
            }
        }
    }

    static func captureCurrentRollback() throws -> RollbackManifest {
        let target = try FileManager.default.destinationOfSymbolicLink(atPath: nodeLink.path)
        try validateInstalledTarget(target)
        var sidecars: [String: String] = [:]
        for suffix in ["dgst"] + (1...17).map({ "dgst.sig.\($0)" }) {
            let link = "\(nodeLink.path).\(suffix)"
            if let value = try? FileManager.default.destinationOfSymbolicLink(atPath: link) {
                sidecars[suffix] = value
            }
        }
        return RollbackManifest(
            binaryTarget: target,
            sidecarTargets: sidecars,
            signatureCheck: currentSignatureCheck(),
            createdAt: Date()
        )
    }

    static func restore(_ rollback: RollbackManifest) throws {
        try validateInstalledTarget(rollback.binaryTarget)
        try configureSignatureCheck(rollback.signatureCheck)
        try atomicSymlink(target: rollback.binaryTarget, link: nodeLink.path)
        for suffix in ["dgst"] + (1...17).map({ "dgst.sig.\($0)" }) {
            let link = "\(nodeLink.path).\(suffix)"
            if let target = rollback.sidecarTargets[suffix] {
                try validateInstalledTarget(target, allowsSidecar: true)
                try atomicSymlink(target: target, link: link)
            } else {
                unlink(link)
            }
        }
    }

    static func validateInstalledTarget(_ target: String, allowsSidecar: Bool = false) throws {
        let standardized = URL(fileURLWithPath: target).standardizedFileURL
        guard standardized.deletingLastPathComponent().path == nodeDirectory.path,
            FileManager.default.fileExists(atPath: standardized.path),
            standardized.lastPathComponent.hasPrefix("node-"),
            !standardized.lastPathComponent.contains("keys"),
            (allowsSidecar || !standardized.lastPathComponent.contains(".dgst"))
        else { throw HelperFailure.invalidManifest("rollback target is outside the fixed node binary directory") }
    }

    static func writeRollback(_ rollback: RollbackManifest) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let temporary = nodeDirectory.appendingPathComponent(".quilnode-rollback-\(getpid()).tmp")
        try encoder.encode(rollback).write(to: temporary, options: [.atomic])
        try setRootPermissions(temporary, mode: 0o600)
        guard rename(temporary.path, rollbackURL.path) == 0 else {
            throw HelperFailure.command("Unable to save the rollback record: \(String(cString: strerror(errno)))")
        }
    }

    static func configureSignatureCheck(_ enabled: Bool) throws {
        var plist = try readPlist()
        var environment = plist["EnvironmentVariables"] as? [String: String] ?? [:]
        environment["QUILIBRIUM_SIGNATURE_CHECK"] = enabled ? "true" : "false"
        plist["EnvironmentVariables"] = environment
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let temporary = "\(plistPath).quilnode-\(getpid()).tmp"
        try data.write(to: URL(fileURLWithPath: temporary), options: [.atomic])
        guard chown(temporary, 0, 0) == 0, chmod(temporary, 0o644) == 0,
            rename(temporary, plistPath) == 0
        else { throw HelperFailure.command("Unable to update the fixed LaunchDaemon signature policy") }
        try validateLaunchDaemonPlist()
    }

    static func currentSignatureCheck() -> Bool {
        let plist = try? readPlist()
        let environment = plist?["EnvironmentVariables"] as? [String: String]
        return environment?["QUILIBRIUM_SIGNATURE_CHECK"] != "false"
    }

    static func readPlist() throws -> [String: Any] {
        let data = try readSecureRegularFile(
            URL(fileURLWithPath: plistPath),
            maximumBytes: 1_000_000,
            requiredOwner: 0
        )
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let plist = object as? [String: Any] else { throw HelperFailure.unsafePlist("it is not a dictionary") }
        return plist
    }

    static func restartAndValidate(
        expectedVersion: String?,
        progress: ServiceOperationReporter? = nil
    ) throws {
        try performLifecycle(.restart)
        // Store recovery and first metrics collection can legitimately exceed
        // 90 seconds after a development update. The operation runs inside the
        // daemon and is polled by the app, so this longer bound does not hold a
        // UI connection or trigger another authorization prompt.
        let startedAt = Date()
        let deadline = startedAt.addingTimeInterval(180)
        var lastDetail = "waiting for process"
        while Date() < deadline {
            Thread.sleep(forTimeInterval: 3)
            let elapsed = min(Int(Date().timeIntervalSince(startedAt)), 180)
            guard isLoaded(), nodeProcessIsRunning() else {
                progress?(
                    .validatingHealth,
                    "Waiting for the node process · health check \(elapsed)s of 180s"
                )
                continue
            }
            do {
                let version = try runNodeTool(["--version"], timeout: 10)
                if let expectedVersion, !version.contains(expectedVersion) {
                    lastDetail = "running binary reports \(version.trimmingCharacters(in: .whitespacesAndNewlines))"
                    progress?(
                        .validatingHealth,
                        "Node is running; waiting for the expected version · \(elapsed)s of 180s"
                    )
                    continue
                }
                let metrics = try runNodeTool(
                    ["--signature-check=\(currentSignatureCheck())", "--metrics"],
                    timeout: 15
                )
                if metrics.contains("libp2p_connected_peers") { return }
                lastDetail = "local metrics are not ready"
                progress?(
                    .validatingHealth,
                    "Node is running; waiting for local metrics · \(elapsed)s of 180s"
                )
            } catch {
                lastDetail = "\(error)"
                progress?(
                    .validatingHealth,
                    "Node startup is still settling · health check \(elapsed)s of 180s"
                )
            }
        }
        throw HelperFailure.healthCheck("Node did not pass its 180-second local startup check (\(lastDetail)).")
    }

}
