import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func stageSignedRelease(
        _ release: SignedReleaseInfo,
        baseURL: URL,
        startedAt: Date,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        guard release.digestPublished,
            release.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures
        else {
            throw UpdateCenterError.signatureQuorumMissing
        }
        let directory = try newStagingDirectory(prefix: "signed-\(release.version)")
        let names =
            [release.binaryFileName, "\(release.binaryFileName).dgst"]
            + release.signatureIndices.map { "\(release.binaryFileName).dgst.sig.\($0)" }
        for (index, name) in names.enumerated() {
            progress(
                NodeUpdateProgress(
                    step: .acquire,
                    phase: index == 0 ? "Downloading signed binary" : "Downloading trust files",
                    detail: "File \(index + 1) of \(names.count): \(name)",
                    fraction: 0.05 + (Double(index) / Double(names.count)) * 0.58,
                    startedAt: startedAt,
                    completedUnits: index,
                    totalUnits: names.count,
                    isEstimate: true
                ))
            try downloadSynchronously(
                baseURL.appendingPathComponent(name),
                to: directory.appendingPathComponent(name),
                maximumBytes: name == release.binaryFileName ? 600_000_000 : 8_192
            )
        }
        let binary = directory.appendingPathComponent(release.binaryFileName)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        progress(
            NodeUpdateProgress(
                step: .verifyTrust,
                phase: "Verifying release trust",
                detail: "Checking SHA3-256 and the Ed448 signature quorum",
                fraction: 0.68,
                startedAt: startedAt,
                completedUnits: 0,
                totalUnits: release.signatureIndices.count,
                isEstimate: true
            ))
        guard
            try verifySignedBundle(binary: binary, signatureIndices: release.signatureIndices)
                >= ReleaseTrustPolicy.minimumSignatures
        else {
            throw UpdateCenterError.signatureQuorumMissing
        }
        progress(
            NodeUpdateProgress(
                step: .inspectArtifact,
                phase: "Validating staged binary",
                detail: "Signature quorum and local SHA-256 checks; runtime probing occurs as the restricted node user",
                fraction: 0.90,
                startedAt: startedAt,
                isEstimate: false
            ))
        guard let hash = sha256(of: binary) else { throw UpdateCenterError.hashFailed }
        let manifest = UpdateActivationManifest(
            channel: "signed", version: release.version,
            binaryFileName: release.binaryFileName, sha256: hash,
            signatureIndices: release.signatureIndices
        )
        return try writeManifest(manifest, directory: directory)
    }

    nonisolated static func stageQClientRelease(
        _ release: OfficialQClientRelease,
        baseURL: URL,
        startedAt: Date,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        let directory = try newStagingDirectory(prefix: "qclient-\(release.releaseVersion)")
        let artifact = try stageQClientArtifact(
            release, directory: directory, baseURL: baseURL,
            startedAt: startedAt, progressStart: 0.05, progressSpan: 0.88,
            progress: progress
        )
        let manifest = QClientActivationManifest(qclient: artifact)
        return try writeTypedManifest(manifest, named: "qclient-install.json", directory: directory)
    }

    nonisolated static func stageMatchingSourceQClient(
        installed: InstalledNodeBuild,
        repositoryURL: String,
        startedAt: Date,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        guard installed.kind == .source,
            let shortCommit = installed.commit,
            let version = installed.version
        else { throw UpdateCenterError.matchingSourceCheckoutUnavailable }
        let workspaceRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/QuilNode/BuildWorkspaces", isDirectory: true)
        let candidates =
            (try? FileManager.default.contentsOfDirectory(
                at: workspaceRoot, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
        var selected: (repository: URL, commit: String)?
        for candidate in candidates where candidate.lastPathComponent.hasPrefix("source-") {
            let repository = candidate.appendingPathComponent("repo", isDirectory: true)
            guard FileManager.default.fileExists(atPath: repository.appendingPathComponent(".git").path),
                let origin = try? runChecked(gitExecutable, ["-C", repository.path, "remote", "get-url", "origin"])
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                origin == repositoryURL,
                let commit = try? runChecked(gitExecutable, ["-C", repository.path, "rev-parse", "HEAD"])
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                commit.hasPrefix(shortCommit)
            else { continue }
            selected = (repository, commit)
            break
        }
        guard let selected else { throw UpdateCenterError.matchingSourceCheckoutUnavailable }
        let seniorityDataset = try prepareSeniorityDataset(in: selected.repository)
        try verifyPinnedCheckoutIsUnmodified(
            selected.repository,
            hydratedSeniorityDataset: seniorityDataset
        )
        let clientManifest = selected.repository.appendingPathComponent("crates/quil-client/Cargo.toml")
        guard FileManager.default.fileExists(atPath: clientManifest.path) else {
            throw UpdateCenterError.sourceQClientMissing
        }
        let built = selected.repository.appendingPathComponent("target/release/qclient")
        let directory = try newStagingDirectory(prefix: "qclient-source-\(shortCommit)")
        let logURL = directory.appendingPathComponent("build.log")
        let workspace = selected.repository.deletingLastPathComponent()
        let sandbox = try prepareSourceBuildSandbox(
            workspace: workspace,
            repository: selected.repository
        )
        progress(
            NodeUpdateProgress(
                step: .acquire,
                phase: "Resolving locked qclient dependencies",
                detail: "Pinned to the installed node commit \(selected.commit.prefix(12))",
                fraction: 0.08, startedAt: startedAt, isEstimate: true, logURL: logURL
            ))
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.fetchProfile,
                executable: sandbox.cargoExecutable,
                arguments: ["fetch", "--locked"]
            ),
            currentDirectory: selected.repository,
            environment: sandbox.environment,
            timeout: 30 * 60,
            logURL: logURL
        )
        progress(
            NodeUpdateProgress(
                step: .client,
                phase: "Compiling matching qclient",
                detail: "Building from the same immutable commit as the installed source node",
                fraction: 0.16, startedAt: startedAt, isEstimate: true, logURL: logURL
            ))
        try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile,
                executable: sandbox.cargoExecutable,
                arguments: ["build", "--release", "--package", "quil-client"]
            ),
            currentDirectory: selected.repository, environment: sandbox.environment,
            timeout: 3 * 60 * 60, logURL: logURL
        )
        try verifyPinnedCheckoutIsUnmodified(
            selected.repository,
            hydratedSeniorityDataset: seniorityDataset
        )
        try validateSourceBuildArtifact(built, maximumBytes: 250_000_000)
        let output = try runChecked(
            SourceBuildSandbox.executable,
            try SourceBuildSandbox.arguments(
                profileURL: sandbox.compileProfile,
                executable: built.path,
                arguments: ["-y", "version"]
            ),
            currentDirectory: selected.repository,
            environment: sandbox.environment,
            timeout: 15
        )
        guard let runtime = QClientRuntimeVersionParser.parse(output) else {
            throw UpdateCenterError.versionValidationFailed
        }
        let fileName = "qclient-\(version)-source-\(selected.commit.prefix(8))-darwin-arm64"
        let staged = directory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: built, to: staged)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
        guard let hash = sha256(of: staged)
        else { throw UpdateCenterError.versionValidationFailed }
        let branch = "detached-\(selected.commit.prefix(8))"
        let info = """
            Quilibrium qclient local source build
            Runtime version: \(runtime)
            Official repository: \(repositoryURL)
            Commit: \(selected.commit)
            Binary SHA-256: \(hash)
            This is NOT an officially signed release binary.
            """
        try info.data(using: String.Encoding.utf8)?.write(
            to: directory.appendingPathComponent("\(fileName).BUILD-INFO.txt"),
            options: Data.WritingOptions.atomic
        )
        let artifact = SignedArtifactActivation(
            kind: .qclient, trust: .pinnedSource,
            releaseVersion: version, reportedVersion: runtime,
            binaryFileName: fileName, sha256: hash, signatureIndices: [],
            branch: branch, commit: selected.commit
        )
        progress(
            NodeUpdateProgress(
                step: .inspectArtifact,
                phase: "Matching qclient verified",
                detail: "Runtime \(runtime) · SHA-256 recorded · exact source commit retained",
                fraction: 0.96, startedAt: startedAt, isEstimate: false, logURL: logURL
            ))
        return try writeTypedManifest(
            QClientActivationManifest(qclient: artifact),
            named: "qclient-install.json", directory: directory
        )
    }

    nonisolated static func stageFirstInstallation(
        node: SignedReleaseInfo,
        qclient: OfficialQClientRelease,
        baseURL: URL,
        startedAt: Date,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        guard node.digestPublished,
            node.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures
        else { throw UpdateCenterError.signatureQuorumMissing }
        let directory = try newStagingDirectory(prefix: "first-install-\(node.version)")
        let nodeNames =
            [node.binaryFileName, "\(node.binaryFileName).dgst"]
            + node.signatureIndices.map { "\(node.binaryFileName).dgst.sig.\($0)" }
        try downloadOfficialBundle(
            names: nodeNames, binaryName: node.binaryFileName,
            maximumBinaryBytes: 600_000_000, directory: directory,
            baseURL: baseURL, startedAt: startedAt,
            progressStart: 0.03, progressSpan: 0.37,
            label: "node", progress: progress
        )
        let nodeBinary = directory.appendingPathComponent(node.binaryFileName)
        guard
            try verifySignedBundle(binary: nodeBinary, signatureIndices: node.signatureIndices)
                >= ReleaseTrustPolicy.minimumSignatures,
            let nodeHash = sha256(of: nodeBinary)
        else { throw UpdateCenterError.versionValidationFailed }
        let nodeArtifact = SignedArtifactActivation(
            kind: .node,
            releaseVersion: node.version,
            reportedVersion: node.version,
            binaryFileName: node.binaryFileName,
            sha256: nodeHash,
            signatureIndices: node.signatureIndices
        )
        let qclientArtifact = try stageQClientArtifact(
            qclient, directory: directory, baseURL: baseURL,
            startedAt: startedAt, progressStart: 0.47, progressSpan: 0.47,
            progress: progress
        )
        progress(
            NodeUpdateProgress(
                step: .sealPlan,
                phase: "Sealing installation plan",
                detail: "Recording independent node and qclient provenance for root re-verification",
                fraction: 0.97, startedAt: startedAt, isEstimate: false
            ))
        return try writeTypedManifest(
            FirstInstallActivationManifest(node: nodeArtifact, qclient: qclientArtifact),
            named: "first-install.json", directory: directory
        )
    }

    nonisolated private static func stageQClientArtifact(
        _ release: OfficialQClientRelease,
        directory: URL,
        baseURL: URL,
        startedAt: Date,
        progressStart: Double,
        progressSpan: Double,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws -> SignedArtifactActivation {
        guard release.digestPublished,
            release.signatureIndices.count >= ReleaseTrustPolicy.minimumSignatures
        else { throw UpdateCenterError.signatureQuorumMissing }
        let names =
            [release.binaryFileName, "\(release.binaryFileName).dgst"]
            + release.signatureIndices.map { "\(release.binaryFileName).dgst.sig.\($0)" }
        try downloadOfficialBundle(
            names: names, binaryName: release.binaryFileName,
            maximumBinaryBytes: 250_000_000, directory: directory,
            baseURL: baseURL, startedAt: startedAt,
            progressStart: progressStart, progressSpan: progressSpan * 0.72,
            label: "qclient", progress: progress
        )
        let binary = directory.appendingPathComponent(release.binaryFileName)
        progress(
            NodeUpdateProgress(
                step: .verifyTrust,
                phase: "Verifying official qclient",
                detail: "Checking SHA3-256 and Ed448 signature quorum",
                fraction: progressStart + progressSpan * 0.78,
                startedAt: startedAt, isEstimate: true
            ))
        guard
            try verifySignedBundle(binary: binary, signatureIndices: release.signatureIndices)
                >= ReleaseTrustPolicy.minimumSignatures
        else { throw UpdateCenterError.signatureQuorumMissing }
        guard let hash = sha256(of: binary)
        else { throw UpdateCenterError.versionValidationFailed }
        return SignedArtifactActivation(
            kind: .qclient,
            releaseVersion: release.releaseVersion,
            // Do not execute downloaded code in the GUI user session. The
            // privileged helper derives this value later from a sandboxed,
            // non-root runtime probe of the root-owned verified copy.
            reportedVersion: nil,
            binaryFileName: release.binaryFileName,
            sha256: hash,
            signatureIndices: release.signatureIndices
        )
    }

    nonisolated private static func downloadOfficialBundle(
        names: [String],
        binaryName: String,
        maximumBinaryBytes: Int,
        directory: URL,
        baseURL: URL,
        startedAt: Date,
        progressStart: Double,
        progressSpan: Double,
        label: String,
        progress: @Sendable (NodeUpdateProgress) -> Void
    ) throws {
        for (index, name) in names.enumerated() {
            progress(
                NodeUpdateProgress(
                    step: .acquire,
                    phase: "Downloading official \(label)",
                    detail: "File \(index + 1) of \(names.count): \(name)",
                    fraction: progressStart + Double(index) / Double(max(names.count, 1)) * progressSpan,
                    startedAt: startedAt, completedUnits: index,
                    totalUnits: names.count, isEstimate: true
                ))
            try downloadSynchronously(
                baseURL.appendingPathComponent(name),
                to: directory.appendingPathComponent(name),
                maximumBytes: name == binaryName ? maximumBinaryBytes : 8_192
            )
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: directory.appendingPathComponent(binaryName).path
        )
    }

    nonisolated private static func writeTypedManifest<T: Encodable>(
        _ manifest: T,
        named name: String,
        directory: URL
    ) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = directory.appendingPathComponent(name)
        try encoder.encode(manifest).write(to: url, options: [.atomic])
        return url
    }

}
