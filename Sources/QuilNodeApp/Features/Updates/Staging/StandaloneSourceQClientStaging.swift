import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func currentQClientSourceHead(
        installed: InstalledNodeBuild, repositoryURL: String
    ) throws -> GitBranchHead {
        guard installed.kind == .source, let version = installed.version,
            let parsed = NodeVersion(version), parsed.components.count >= 4
        else { throw UpdateCenterError.matchingSourceCheckoutUnavailable }
        let branch = "v" + parsed.components.prefix(4).map(String.init).joined(separator: ".")
        let reference = "refs/heads/\(branch)"
        let output = try runChecked(
            gitExecutable, ["ls-remote", "--refs", "--heads", repositoryURL, reference],
            environment: sourceControlEnvironment(), timeout: 30, maximumOutputBytes: 4_096
        )
        let refs = try canonicalRemoteReferences(output)
        guard refs.count == 1 else { throw UpdateCenterError.noOfficialBranches }
        let fields = refs[0].split(separator: "\t")
        guard fields.count == 2, fields[1] == reference else { throw UpdateCenterError.noOfficialBranches }
        return GitBranchHead(
            name: branch, commit: String(fields[0]), committedAt: Date(),
            subject: "Client source selected from the installed protocol branch"
        )
    }

    nonisolated static func stageStandaloneSourceQClient(
        installed: InstalledNodeBuild, head: GitBranchHead, repositoryURL: String,
        startedAt: Date, progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) throws -> URL {
        guard installed.kind == .source,
            QClientCompatibility.isCompatible(qclientReleaseVersion: head.version, nodeVersion: installed.version)
        else { throw UpdateCenterError.versionValidationFailed }
        if let cached = try cachedSourceQClientManifest(installed: installed, head: head) {
            progress(
                NodeUpdateProgress(
                    step: .client, phase: "Retrying verified client installation",
                    detail: "Reusing the compiled client for \(head.commit.prefix(12)); no rebuild is needed.",
                    fraction: 1, startedAt: startedAt, isEstimate: false
                ))
            return cached
        }
        let context = try prepareSourceBuildContext(
            head: head, repositoryURL: repositoryURL, startedAt: startedAt,
            channel: "qclient", displayVersion: nil, progress: progress
        )
        let clientVersion = try expectedQClientRuntimeVersion(
            repository: context.repository, sourceVersion: context.sourceVersion
        )
        guard let nodeVersion = installed.version,
            let node = NodeVersion(nodeVersion), let client = NodeVersion(clientVersion),
            Array(node.components.prefix(4)) == Array(client.components.prefix(4)), client >= node,
            let artifact = try stageSourceQClient(context: context, existing: nil, progress: progress)
        else { throw UpdateCenterError.versionValidationFailed }
        return try writeTypedManifest(
            QClientActivationManifest(qclient: artifact), named: "qclient-install.json", directory: context.directory
        )
    }
}
