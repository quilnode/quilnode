import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func validateStage(_ stage: URL, manifestURL: URL) throws {
        let acceptedManifestNames = ["activation.json", "first-install.json", "qclient-install.json"]
        guard acceptedManifestNames.contains(manifestURL.lastPathComponent) else {
            throw HelperFailure.unsafeStage("the manifest name is not an accepted typed activation manifest")
        }
        let pattern = #"^/Users/[^/]+/Library/Application Support/QuilNode/UpdateStaging/[A-Za-z0-9._-]+$"#
        guard stage.path.range(of: pattern, options: .regularExpression) != nil else {
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
}
