import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func installQClient(manifestPath: String) throws {
        let manifestURL = URL(fileURLWithPath: manifestPath).standardizedFileURL
        let stage = manifestURL.deletingLastPathComponent()
        try validateStage(stage, manifestURL: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
            QClientActivationManifest.self,
            from: readSecureRegularFile(manifestURL, maximumBytes: 64_000)
        )
        guard manifest.schemaVersion == 1,
            Date().timeIntervalSince(manifest.createdAt) >= -300,
            Date().timeIntervalSince(manifest.createdAt) < 7 * 24 * 60 * 60
        else { throw HelperFailure.invalidManifest("the qclient activation manifest is invalid or expired") }
        try validateQClientArtifact(manifest.qclient, stage: stage)
        if manifest.qclient.trust == .officialSigned {
            try verifyOfficialArtifact(manifest.qclient, stage: stage, maximumBinaryBytes: 250_000_000)
        }
        _ = try installManagedQClient(manifest.qclient, stage: stage)
    }

    @discardableResult
    static func installManagedQClient(
        _ artifact: SignedArtifactActivation,
        stage: URL
    ) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: qclientRoot, withIntermediateDirectories: true)
        try setRootPermissions(qclientRoot, mode: 0o755)
        let releaseDirectory = qclientRoot.appendingPathComponent(artifact.releaseVersion, isDirectory: true)
        try fm.createDirectory(at: releaseDirectory, withIntermediateDirectories: true)
        try setRootPermissions(releaseDirectory, mode: 0o755)
        let source = stage.appendingPathComponent(artifact.binaryFileName)
        let destination = releaseDirectory.appendingPathComponent(artifact.binaryFileName)
        if fm.fileExists(atPath: destination.path) {
            guard sha256(destination) == artifact.sha256 else {
                throw HelperFailure.invalidManifest("a different qclient already uses this release filename")
            }
        } else {
            try fm.copyItem(at: source, to: destination)
        }
        try setRootPermissions(destination, mode: 0o755)
        guard sha256(destination) == artifact.sha256 else {
            throw HelperFailure.invalidManifest("the installed qclient SHA-256 changed during installation")
        }
        let sidecarNames =
            artifact.trust == .officialSigned
            ? ["\(artifact.binaryFileName).dgst"]
                + artifact.signatureIndices.map({ "\(artifact.binaryFileName).dgst.sig.\($0)" })
            : ["\(artifact.binaryFileName).BUILD-INFO.txt"]
        for name in sidecarNames {
            let staged = stage.appendingPathComponent(name)
            try validateRegularFile(staged, maximumBytes: 64_000)
            let installed = releaseDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: installed.path) {
                guard sha256(installed) == sha256(staged) else {
                    throw HelperFailure.invalidManifest("a different qclient trust sidecar already uses \(name)")
                }
            } else {
                try fm.copyItem(at: staged, to: installed)
            }
            try setRootPermissions(installed, mode: 0o644)
        }
        if artifact.trust == .officialSigned {
            // Re-verify the root-owned copy, not only the user-writable staged
            // file. This guarantees the executable below is the exact quorum-
            // signed artifact even if staging changed during the copy.
            try verifyOfficialArtifact(
                artifact,
                stage: releaseDirectory,
                maximumBinaryBytes: 250_000_000
            )
        }
        let trustArguments = artifact.trust == .officialSigned ? ["--signature-check=false"] : ["-y"]
        // Candidate code must never execute as root. Official signatures prove
        // publisher authenticity, not memory safety; source builds have no
        // release signature at all. The restricted node account is therefore
        // the execution boundary for both provenance classes.
        let runtimeOutput = try runArtifactVersionProbe(
            destination,
            trustArguments + ["version"],
            timeout: 15
        )
        let reported = artifact.reportedVersion ?? qclientRuntimeVersion(runtimeOutput)
        guard let reported, runtimeOutput.contains(reported) else {
            throw HelperFailure.invalidManifest("installed qclient runtime version does not match staged provenance")
        }
        let record = ManagedQClientRecord(
            releaseVersion: artifact.releaseVersion,
            trust: artifact.trust,
            reportedVersion: reported,
            binaryFileName: artifact.binaryFileName,
            sha256: artifact.sha256,
            signatureIndices: artifact.signatureIndices.sorted(),
            branch: artifact.branch,
            commit: artifact.commit,
            installedAt: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try writeRootFile(try encoder.encode(record), to: qclientRecordURL.path, mode: 0o600)
        _ = try trustedQClient()
        return destination
    }

    static func inspectManagedQClient() -> ServiceQClientStatus {
        do {
            let (binary, record) = try trustedQClient()
            return ServiceQClientStatus(
                state: .verified,
                releaseVersion: record.releaseVersion,
                reportedVersion: record.reportedVersion,
                binaryFileName: binary.lastPathComponent,
                trust: record.trust,
                commit: record.commit,
                sha256: record.sha256,
                signatureCount: record.signatureIndices.count,
                installedAt: record.installedAt,
                detail: record.trust == .officialSigned
                    ? "Official qclient is root-owned and matches its recorded signed-release provenance."
                    : "Source qclient is root-owned and matches the installed node's recorded commit and SHA-256 provenance."
            )
        } catch {
            let missing = !FileManager.default.fileExists(atPath: qclientRecordURL.path)
            return ServiceQClientStatus(
                state: missing ? .missing : .invalid,
                releaseVersion: nil,
                reportedVersion: nil,
                binaryFileName: nil,
                trust: nil,
                commit: nil,
                sha256: nil,
                signatureCount: 0,
                installedAt: nil,
                detail: missing
                    ? "A matching managed qclient has not been installed yet."
                    : "Managed qclient failed validation: \(error)"
            )
        }
    }

    static func trustedQClient() throws -> (URL, ManagedQClientRecord) {
        try validateRegularFile(qclientRecordURL, maximumBytes: 32_000)
        var recordInfo = stat()
        guard lstat(qclientRecordURL.path, &recordInfo) == 0,
            recordInfo.st_uid == 0, recordInfo.st_gid == 0,
            recordInfo.st_mode & 0o077 == 0
        else { throw HelperFailure.service("qclient provenance ownership or mode is unsafe") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(
            ManagedQClientRecord.self,
            from: readSecureRegularFile(
                qclientRecordURL,
                maximumBytes: 32_000,
                requiredOwner: 0
            )
        )
        let expectedName: String
        switch record.trust {
        case .officialSigned:
            expectedName = "qclient-\(record.releaseVersion)-darwin-arm64"
        case .pinnedSource:
            guard let commit = record.commit,
                commit.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil,
                let branch = record.branch, !branch.isEmpty, branch.count <= 200
            else { throw HelperFailure.service("source qclient provenance is malformed") }
            expectedName = "qclient-\(record.releaseVersion)-source-\(commit.prefix(8))-darwin-arm64"
        }
        guard record.schemaVersion == 1,
            record.binaryFileName == expectedName,
            record.sha256.range(of: #"^[0-9a-f]{64}$"#, options: .regularExpression) != nil,
            record.reportedVersion.range(of: #"^[0-9]+\.[0-9]+\.[0-9]+-p[0-9]+$"#, options: .regularExpression) != nil,
            (record.trust == .pinnedSource
                ? record.signatureIndices.isEmpty
                : (record.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures
                    && Set(record.signatureIndices).count == record.signatureIndices.count
                    && record.signatureIndices.allSatisfy({ (1...17).contains($0) })))
        else { throw HelperFailure.service("qclient provenance is malformed") }
        let binary =
            qclientRoot
            .appendingPathComponent(record.releaseVersion, isDirectory: true)
            .appendingPathComponent(record.binaryFileName)
        try validateRootOwnedExecutable(binary, maximumBytes: 250_000_000)
        guard sha256(binary) == record.sha256 else {
            throw HelperFailure.service("managed qclient no longer matches its recorded SHA-256")
        }
        return (binary, record)
    }

}
