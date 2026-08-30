import CryptoKit
import Darwin
import Foundation
import Security

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

    static func freshInstall(manifestPath: String) throws {
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

        _ = try installManagedQClient(firstInstall.qclient, stage: stage)
        let installedBinary = try installVerifiedNodeCandidate(manifest, stage: stage)
        try switchLinks(to: installedBinary, manifest: manifest)
        try ensureFileDescriptorLimits()
        try writeNodeServicePlist(signatureCheck: true)
        do {
            if isLoaded() {
                try runLaunchctl(["kickstart", "-k", serviceTarget])
            } else {
                try runLaunchctl(["bootstrap", "system", plistPath])
            }
            try restartAndValidate(expectedVersion: manifest.reportedVersion ?? manifest.version)
        } catch {
            _ = try? runLaunchctl(["bootout", "system", plistPath])
            throw HelperFailure.healthCheck(
                "First startup did not pass local health checks: \(error). The downloaded binary and any newly generated identity remain local for diagnosis; no existing keyset or store was removed."
            )
        }
    }

    static func activate(manifestPath: String) throws {
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
            let installedBinary = try installVerifiedNodeCandidate(manifest, stage: stage)
            try configureSignatureCheck(manifest.channel == "signed")
            try switchLinks(to: installedBinary, manifest: manifest)
            try restartAndValidate(expectedVersion: manifest.reportedVersion ?? manifest.version)
            try? refreshManagedFirewallAfterUpdate()
            if let qclient = manifest.qclient {
                _ = try installManagedQClient(qclient, stage: stage)
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

    static func validateStage(_ stage: URL, manifestURL: URL) throws {
        let acceptedManifestNames = ["activation.json", "first-install.json", "qclient-install.json"]
        guard acceptedManifestNames.contains(manifestURL.lastPathComponent) else {
            throw HelperFailure.unsafeStage("the manifest name is not an accepted typed activation manifest")
        }
        let path = stage.path
        let pattern = #"^/Users/[^/]+/Library/Application Support/QuilNode/UpdateStaging/[A-Za-z0-9._-]+$"#
        guard path.range(of: pattern, options: .regularExpression) != nil else {
            throw HelperFailure.unsafeStage("the path is outside QuilNode's fixed UpdateStaging directory")
        }
        var current = URL(fileURLWithPath: "/")
        for component in stage.pathComponents.dropFirst() {
            current.appendPathComponent(component)
            var info = stat()
            guard lstat(current.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFLNK else {
                throw HelperFailure.unsafeStage("a path component is missing or symbolic")
            }
        }
        var stageInfo = stat()
        var manifestInfo = stat()
        guard lstat(stage.path, &stageInfo) == 0,
            (stageInfo.st_mode & S_IFMT) == S_IFDIR,
            stageInfo.st_uid != 0,
            stageInfo.st_mode & 0o077 == 0,
            lstat(manifestURL.path, &manifestInfo) == 0,
            (manifestInfo.st_mode & S_IFMT) == S_IFREG,
            manifestInfo.st_uid == stageInfo.st_uid
        else {
            throw HelperFailure.unsafeStage(
                "the staging directory must be private and owned by the manifest's user"
            )
        }
        try validateRegularFile(manifestURL, maximumBytes: 64_000)
    }

    static func validate(_ manifest: ActivationManifest, stage: URL) throws {
        let sourceChannels = ["source", "approved-dev", "raw-dev"]
        let versionPattern = #"^[0-9]+(?:\.[0-9]+){2,}$"#
        let manifestAge = Date().timeIntervalSince(manifest.createdAt)
        guard (1...2).contains(manifest.schemaVersion),
            manifest.channel == "signed" || sourceChannels.contains(manifest.channel),
            manifestAge >= -300,
            manifestAge < 7 * 24 * 60 * 60,
            manifest.sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
            manifest.version.range(of: versionPattern, options: .regularExpression) != nil,
            manifest.reportedVersion?.range(of: versionPattern, options: .regularExpression) != nil
                || manifest.reportedVersion == nil
        else { throw HelperFailure.invalidManifest("schema, channel, date, version, or hash is invalid") }

        let signedPattern = #"^node-[0-9]+(?:\.[0-9]+){2,}-darwin-arm64$"#
        let sourcePattern = #"^node-[0-9]+(?:\.[0-9]+){2,}-source-[0-9a-f]{8}-darwin-arm64$"#
        let expectedPattern = manifest.channel == "signed" ? signedPattern : sourcePattern
        guard manifest.binaryFileName.range(of: expectedPattern, options: .regularExpression) != nil,
            manifest.binaryFileName.contains(manifest.version)
        else { throw HelperFailure.invalidManifest("the binary filename is invalid") }
        if sourceChannels.contains(manifest.channel) {
            guard let commit = manifest.commit,
                commit.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil,
                manifest.binaryFileName.contains(String(commit.prefix(8))),
                let branch = manifest.branch, !branch.isEmpty, branch.count <= 200
            else { throw HelperFailure.invalidManifest("source provenance is incomplete") }
            guard manifest.signatureIndices.isEmpty else {
                throw HelperFailure.invalidManifest("a source build cannot claim release signatures")
            }
            if let qclient = manifest.qclient {
                try validateQClientArtifact(qclient, stage: stage)
                guard qclient.trust == .pinnedSource,
                    qclient.commit == manifest.commit,
                    qclient.branch == manifest.branch
                else { throw HelperFailure.invalidManifest("source node and qclient provenance do not match") }
            }
        } else {
            guard manifest.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures,
                Set(manifest.signatureIndices).count == manifest.signatureIndices.count,
                manifest.signatureIndices.allSatisfy({ (1...17).contains($0) })
            else { throw HelperFailure.invalidManifest("the signed release quorum is incomplete") }
            guard manifest.qclient == nil else {
                throw HelperFailure.invalidManifest("signed node updates cannot smuggle a second executable")
            }
        }
        try validateRegularFile(stage.appendingPathComponent(manifest.binaryFileName), maximumBytes: 600_000_000)
    }

    /// Re-verifies the official trust bundle inside the root boundary. The
    /// service does not trust the GUI's prior verification or signature count.
    static func verifySignedRelease(_ manifest: ActivationManifest, stage: URL) throws {
        try validateRootOwnedExecutable(
            URL(fileURLWithPath: operatorVerifier), maximumBytes: 40_000_000
        )
        let binary = stage.appendingPathComponent(manifest.binaryFileName)
        let digest = stage.appendingPathComponent("\(manifest.binaryFileName).dgst")
        try validateRegularFile(digest, maximumBytes: 8_192)
        guard
            let digestText = String(
                data: try readSecureRegularFile(digest, maximumBytes: 8_192),
                encoding: .utf8
            )
        else { throw HelperFailure.invalidManifest("the published digest is not UTF-8") }
        let escapedName = NSRegularExpression.escapedPattern(for: manifest.binaryFileName)
        let pattern = "^SHA3-256\\(\(escapedName)\\)= ([0-9a-fA-F]{64})\\n?$"
        let expression = try NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(digestText.startIndex..<digestText.endIndex, in: digestText)
        guard let match = expression.firstMatch(in: digestText, range: fullRange),
            match.range == fullRange,
            let claimedRange = Range(match.range(at: 1), in: digestText)
        else { throw HelperFailure.invalidManifest("the published SHA3-256 digest is malformed") }
        let claimed = digestText[claimedRange].lowercased()
        let computed = try run(
            URL(fileURLWithPath: operatorVerifier),
            ["sha3-256", binary.path], timeout: 120
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard computed.count == 64, computed.lowercased() == claimed else {
            throw HelperFailure.invalidManifest("the staged binary does not match the published SHA3-256 digest")
        }

        var verified = 0
        for index in manifest.signatureIndices {
            guard ReleaseTrustPolicy.signatories.indices.contains(index - 1) else {
                throw HelperFailure.invalidManifest("the release signature index is invalid")
            }
            let signature = stage.appendingPathComponent("\(manifest.binaryFileName).dgst.sig.\(index)")
            try validateRegularFile(signature, maximumBytes: 256)
            _ = try run(
                URL(fileURLWithPath: operatorVerifier),
                ["verify-ed448", ReleaseTrustPolicy.signatories[index - 1], signature.path, digest.path],
                timeout: 15
            )
            verified += 1
        }
        guard verified >= ReleaseTrustPolicy.minimumSignatures else {
            throw HelperFailure.invalidManifest("the official Ed448 signature quorum was not verified")
        }
    }

    static func validateQClientArtifact(
        _ artifact: SignedArtifactActivation,
        stage: URL
    ) throws {
        let versionPattern = #"^[0-9]+(?:\.[0-9]+){2,}$"#
        let runtimePattern = #"^[0-9]+\.[0-9]+\.[0-9]+-p[0-9]+$"#
        let signedFilePattern = #"^qclient-[0-9]+(?:\.[0-9]+){2,}-darwin-arm64$"#
        let sourceFilePattern = #"^qclient-[0-9]+(?:\.[0-9]+){2,}-source-[0-9a-f]{8}-darwin-arm64$"#
        guard artifact.kind == .qclient,
            artifact.releaseVersion.range(of: versionPattern, options: .regularExpression) != nil,
            artifact.sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
            artifact.reportedVersion == nil
                || artifact.reportedVersion?.range(of: runtimePattern, options: .regularExpression) != nil
        else {
            throw HelperFailure.invalidManifest(
                "qclient provenance, version, filename, hash, or signature quorum is invalid")
        }
        switch artifact.trust {
        case .officialSigned:
            guard artifact.binaryFileName.range(of: signedFilePattern, options: .regularExpression) != nil,
                artifact.binaryFileName == "qclient-\(artifact.releaseVersion)-darwin-arm64",
                artifact.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures,
                Set(artifact.signatureIndices).count == artifact.signatureIndices.count,
                artifact.signatureIndices.allSatisfy({ (1...17).contains($0) }),
                artifact.branch == nil, artifact.commit == nil
            else { throw HelperFailure.invalidManifest("official qclient trust provenance is incomplete") }
        case .pinnedSource:
            guard artifact.reportedVersion != nil,
                artifact.binaryFileName.range(of: sourceFilePattern, options: .regularExpression) != nil,
                let commit = artifact.commit,
                commit.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil,
                artifact.binaryFileName == "qclient-\(artifact.releaseVersion)-source-\(commit.prefix(8))-darwin-arm64",
                let branch = artifact.branch, !branch.isEmpty, branch.count <= 200,
                artifact.signatureIndices.isEmpty
            else { throw HelperFailure.invalidManifest("source qclient trust provenance is incomplete") }
        }
        try validateRegularFile(
            stage.appendingPathComponent(artifact.binaryFileName),
            maximumBytes: 250_000_000
        )
    }

    /// Generic root-boundary verification for official artifacts. The GUI's
    /// verification is useful feedback, never an authority decision.
    static func verifyOfficialArtifact(
        _ artifact: SignedArtifactActivation,
        stage: URL,
        maximumBinaryBytes: UInt64
    ) throws {
        try validateRootOwnedExecutable(
            URL(fileURLWithPath: operatorVerifier), maximumBytes: 40_000_000
        )
        let binary = stage.appendingPathComponent(artifact.binaryFileName)
        try validateRegularFile(binary, maximumBytes: maximumBinaryBytes)
        let digest = stage.appendingPathComponent("\(artifact.binaryFileName).dgst")
        try validateRegularFile(digest, maximumBytes: 8_192)
        guard
            let digestText = String(
                data: try readSecureRegularFile(digest, maximumBytes: 8_192),
                encoding: .utf8
            )
        else { throw HelperFailure.invalidManifest("the qclient digest is not UTF-8") }
        let escapedName = NSRegularExpression.escapedPattern(for: artifact.binaryFileName)
        let expression = try NSRegularExpression(
            pattern: "^SHA3-256\\(\(escapedName)\\)= ([0-9a-fA-F]{64})\\n?$"
        )
        let fullRange = NSRange(digestText.startIndex..<digestText.endIndex, in: digestText)
        guard let match = expression.firstMatch(in: digestText, range: fullRange),
            match.range == fullRange,
            let claimedRange = Range(match.range(at: 1), in: digestText)
        else { throw HelperFailure.invalidManifest("the qclient SHA3-256 digest is malformed") }
        let computed = try run(
            URL(fileURLWithPath: operatorVerifier), ["sha3-256", binary.path], timeout: 120
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard computed.lowercased() == digestText[claimedRange].lowercased(),
            sha256(binary) == artifact.sha256.lowercased()
        else { throw HelperFailure.invalidManifest("qclient does not match its signed digest or staged SHA-256") }

        var verified = 0
        for index in artifact.signatureIndices {
            guard ReleaseTrustPolicy.signatories.indices.contains(index - 1) else {
                throw HelperFailure.invalidManifest("the qclient signature index is invalid")
            }
            let signature = stage.appendingPathComponent("\(artifact.binaryFileName).dgst.sig.\(index)")
            try validateRegularFile(signature, maximumBytes: 256)
            _ = try run(
                URL(fileURLWithPath: operatorVerifier),
                ["verify-ed448", ReleaseTrustPolicy.signatories[index - 1], signature.path, digest.path],
                timeout: 15
            )
            verified += 1
        }
        guard verified >= ReleaseTrustPolicy.minimumSignatures else {
            throw HelperFailure.invalidManifest("the official qclient signature quorum was not verified")
        }
    }

}
