import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func currentNodePID() -> Int32? {
        guard let output = try? runLaunchctl(["print", serviceTarget]),
            let regex = try? NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)\s*$"#),
            let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
            let range = Range(match.range(at: 1), in: output)
        else { return nil }
        return Int32(output[range])
    }

    /// Source candidates remain outside the default passwordless boundary.
    /// The authenticated app may persist one explicit, root-owned automatic
    /// channel policy; every other source channel still requires fresh macOS
    /// user presence.
    static func nodeActivationRequiresAuthorization(
        manifestPath: String
    ) throws -> Bool {
        let manifestURL = URL(fileURLWithPath: manifestPath).standardizedFileURL
        try validateStage(manifestURL.deletingLastPathComponent(), manifestURL: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            ActivationManifest.self,
            from: readSecureRegularFile(manifestURL, maximumBytes: 64_000)
        )
        return !automaticNodeUpdatePolicyPermits(channel: manifest.channel)
    }

    static func qclientInstallRequiresAuthorization(
        manifestPath: String
    ) throws -> Bool {
        let manifestURL = URL(fileURLWithPath: manifestPath).standardizedFileURL
        try validateStage(manifestURL.deletingLastPathComponent(), manifestURL: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            QClientActivationManifest.self,
            from: readSecureRegularFile(manifestURL, maximumBytes: 64_000)
        )
        return manifest.qclient.trust != .officialSigned
    }

    static func freshInstall(
        manifestPath: String,
        progress: ServiceOperationReporter? = nil
    ) throws {
        progress?(.validatingPlan, "Validating the sealed first-install plan.")
        let manifestURL = URL(fileURLWithPath: manifestPath).standardizedFileURL
        let stage = manifestURL.deletingLastPathComponent()
        try validateStage(stage, manifestURL: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let firstInstall = try decoder.decode(
            FirstInstallActivationManifest.self,
            from: readSecureRegularFile(manifestURL, maximumBytes: 64_000)
        )
        guard firstInstall.schemaVersion == 1,
            Date().timeIntervalSince(firstInstall.createdAt) >= -300,
            Date().timeIntervalSince(firstInstall.createdAt) < 7 * 24 * 60 * 60,
            firstInstall.node.kind == .node,
            firstInstall.node.trust == .officialSigned,
            firstInstall.qclient.kind == .qclient,
            firstInstall.qclient.trust == .officialSigned
        else { throw HelperFailure.invalidManifest("the first-install manifest is invalid or expired") }
        let nodeArtifact = firstInstall.node
        let manifest = ActivationManifest(
            schemaVersion: 2,
            channel: "signed",
            version: nodeArtifact.releaseVersion,
            reportedVersion: nodeArtifact.reportedVersion,
            branch: nil,
            commit: nil,
            binaryFileName: nodeArtifact.binaryFileName,
            sha256: nodeArtifact.sha256,
            createdAt: firstInstall.createdAt,
            signatureIndices: nodeArtifact.signatureIndices,
            qclient: nil
        )
        try validate(manifest, stage: stage)
        guard manifest.channel == "signed" else {
            throw HelperFailure.invalidManifest("first installation requires an official signed release")
        }
        try validateQClientArtifact(firstInstall.qclient, stage: stage)
        progress?(.verifyingArtifact, "Re-verifying the staged qclient inside the privileged boundary.")
        try verifyOfficialArtifact(firstInstall.qclient, stage: stage, maximumBinaryBytes: 250_000_000)
        let stagedBinary = stage.appendingPathComponent(manifest.binaryFileName)
        guard sha256(stagedBinary) == manifest.sha256.lowercased() else {
            throw HelperFailure.invalidManifest("the staged binary SHA-256 does not match")
        }

        if FileManager.default.fileExists(atPath: nodeLink.path) {
            let target = try FileManager.default.destinationOfSymbolicLink(atPath: nodeLink.path)
            let installed = URL(fileURLWithPath: target)
            guard installed.lastPathComponent == manifest.binaryFileName,
                sha256(installed) == manifest.sha256
            else {
                throw HelperFailure.service(
                    "a different node installation already exists; use the transactional update path")
            }
        }
        if FileManager.default.fileExists(atPath: plistPath) {
            try validateLaunchDaemonPlist()
        }

        try FileManager.default.createDirectory(at: nodeDirectory, withIntermediateDirectories: true)
        guard chown(nodeDirectory.path, 0, 0) == 0, chmod(nodeDirectory.path, 0o755) == 0 else {
            throw HelperFailure.command("Unable to secure the node installation directory")
        }
        let config = nodeDirectory.appendingPathComponent(".config", isDirectory: true)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
        guard chown(config.path, serviceUID, serviceGID) == 0, chmod(config.path, 0o700) == 0 else {
            throw HelperFailure.command("Unable to prepare the private node configuration directory")
        }
        for name in ["node.log", "node-error.log"] {
            let log = nodeDirectory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: log.path) {
                guard FileManager.default.createFile(atPath: log.path, contents: nil) else {
                    throw HelperFailure.command("Unable to prepare local node logs")
                }
            }
            guard chown(log.path, serviceUID, serviceGID) == 0,
                chmod(log.path, 0o644) == 0
            else { throw HelperFailure.command("Unable to prepare local node logs") }
        }

        _ = try installManagedQClient(firstInstall.qclient, stage: stage, progress: progress)
        progress?(.installingFiles, "Installing the verified node runtime and launchd configuration.")
        let installedBinary = try installVerifiedNodeCandidate(manifest, stage: stage)
        try switchLinks(to: installedBinary, manifest: manifest)
        try ensureFileDescriptorLimits()
        try writeNodeServicePlist(signatureCheck: true)
        do {
            progress?(.activatingRuntime, "Starting the restricted Quilibrium node runtime.")
            if isLoaded() {
                try runLaunchctl(["kickstart", "-k", serviceTarget])
            } else {
                try runLaunchctl(["bootstrap", "system", plistPath])
            }
            progress?(.validatingHealth, "Validating the node process, version, and local metrics.")
            try restartAndValidate(expectedVersion: manifest.reportedVersion ?? manifest.version)
        } catch {
            _ = try? runLaunchctl(["bootout", "system", plistPath])
            throw HelperFailure.healthCheck(
                "First startup did not pass local health checks: \(error). The downloaded binary and any newly generated identity remain local for diagnosis; no existing keyset or store was removed."
            )
        }
    }

    static func activate(
        manifestPath: String,
        progress: ServiceOperationReporter? = nil
    ) throws {
        progress?(.validatingPlan, "Validating the sealed node activation plan.")
        let manifestURL = URL(fileURLWithPath: manifestPath).standardizedFileURL
        let stage = manifestURL.deletingLastPathComponent()
        try validateStage(stage, manifestURL: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            ActivationManifest.self,
            from: readSecureRegularFile(manifestURL, maximumBytes: 64_000)
        )
        try validate(manifest, stage: stage)

        let stagedBinary = stage.appendingPathComponent(manifest.binaryFileName)
        guard sha256(stagedBinary) == manifest.sha256.lowercased() else {
            throw HelperFailure.invalidManifest("the staged binary SHA-256 does not match")
        }
        let previous = try captureCurrentRollback()
        try writeRollback(previous)
        do {
            progress?(.installingFiles, "Installing the verified node candidate and rollback point.")
            let installedBinary = try installVerifiedNodeCandidate(manifest, stage: stage)
            try configureSignatureCheck(manifest.channel == "signed")
            try switchLinks(to: installedBinary, manifest: manifest)
            progress?(.activatingRuntime, "Switching to the verified node runtime.")
            progress?(.validatingHealth, "Validating the updated node and local metrics.")
            try restartAndValidate(expectedVersion: manifest.reportedVersion ?? manifest.version)
            try? refreshManagedFirewallAfterUpdate()
            if let qclient = manifest.qclient {
                _ = try installManagedQClient(qclient, stage: stage, progress: progress)
            }
            print("Installed \(manifest.version) from \(manifest.channel); startup and local metrics passed.")
        } catch {
            let updateError = error
            do {
                try restore(previous)
                try restartAndValidate(expectedVersion: nil)
            } catch {
                throw HelperFailure.healthCheck(
                    "Update failed and automatic restoration could not be verified: \(updateError). Restoration error: \(error)"
                )
            }
            throw HelperFailure.healthCheck(
                "Update failed; the previous binary was restored and passed local health checks: \(updateError)"
            )
        }
    }

    static func rollback() throws {
        guard
            let data = try? readSecureRegularFile(
                rollbackURL,
                maximumBytes: 64_000,
                requiredOwner: 0
            )
        else { throw HelperFailure.noRollback }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let target = try decoder.decode(RollbackManifest.self, from: data)
        try validateInstalledTarget(target.binaryTarget)
        let current = try captureCurrentRollback()
        try restore(target)
        try restartAndValidate(expectedVersion: nil)
        try? refreshManagedFirewallAfterUpdate()
        try writeRollback(current)
        print(
            "Rolled back to \(URL(fileURLWithPath: target.binaryTarget).lastPathComponent); startup and local metrics passed."
        )
    }

}
