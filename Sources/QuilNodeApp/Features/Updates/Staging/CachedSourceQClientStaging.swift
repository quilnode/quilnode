import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    /// Retry activation using the exact compiled candidate. Recheck its hash
    /// and selected upstream commit; the helper independently validates the
    /// complete plan again before installation and administrator approval.
    nonisolated static func cachedSourceQClientManifest(
        installed: InstalledNodeBuild, head: GitBranchHead, root: URL? = nil
    ) throws -> URL? {
        let staging = try root ?? applicationSupportDirectory().appendingPathComponent("UpdateStaging")
        let candidates =
            (try? FileManager.default.contentsOfDirectory(
                at: staging, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
            )) ?? []
        let matching = candidates.filter { $0.lastPathComponent.hasPrefix("source-\(head.commit.prefix(8))-") }
            .sorted {
                ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
                    > ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
            }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for directory in matching.prefix(32) {
            let manifestURL = directory.appendingPathComponent("qclient-install.json")
            guard let data = try? BoundedLocalData.read(from: manifestURL, maximumBytes: 64_000),
                let manifest = try? decoder.decode(QClientActivationManifest.self, from: data),
                manifest.schemaVersion == 1,
                Date().timeIntervalSince(manifest.createdAt) >= -300,
                Date().timeIntervalSince(manifest.createdAt) < 7 * 24 * 60 * 60
            else { continue }
            let artifact = manifest.qclient
            guard artifact.kind == .qclient, artifact.trust == .pinnedSource,
                artifact.commit == head.commit, artifact.branch == head.name,
                !artifact.binaryFileName.contains("/"), !artifact.binaryFileName.hasPrefix("."),
                let version = NodeVersion(artifact.reportedVersion ?? ""),
                let node = NodeVersion(installed.version ?? ""), version >= node,
                Array(version.components.prefix(4)) == Array(node.components.prefix(4))
            else { continue }
            let binary = directory.appendingPathComponent(artifact.binaryFileName)
            guard (try? validateSourceBuildArtifact(binary, maximumBytes: 250_000_000)) != nil,
                sha256(of: binary) == artifact.sha256
            else { continue }
            return manifestURL
        }
        return nil
    }
}
