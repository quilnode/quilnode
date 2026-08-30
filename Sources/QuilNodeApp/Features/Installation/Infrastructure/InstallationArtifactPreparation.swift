import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct PreparedFirstInstallationAssets {
    let nodeRelease: SignedReleaseInfo
    let qclientRelease: OfficialQClientRelease
    let manifestURL: URL
}

struct PreparedQClientAsset {
    let officialRelease: OfficialQClientRelease?
    let manifestURL: URL
}

/// Stages public installation artifacts without mutating coordinator state.
/// The caller owns presentation progress and the later privileged activation.
enum InstallationArtifactPreparation {
    private static let releaseBaseURL = URL(string: "https://releases.quilibrium.com/")!
    private static let nodeReleaseURL = URL(string: "https://releases.quilibrium.com/release")!
    private static let qclientReleaseURL = URL(string: "https://releases.quilibrium.com/qclient-release")!
    private static let repositoryURL = "https://github.com/QuilibriumNetwork/monorepo.git"

    static func stageFirstInstallation(
        startedAt: Date,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) async throws -> PreparedFirstInstallationAssets {
        async let nodeRelease = ReleaseChecker.fetchSignedRelease(endpoint: nodeReleaseURL)
        async let qclientRelease = ReleaseChecker.fetchSignedQClientRelease(endpoint: qclientReleaseURL)
        let (node, qclient) = try await (nodeRelease, qclientRelease)
        let manifestURL = try await Task.detached(priority: .utility) {
            try ReleaseChecker.stageFirstInstallation(
                node: node,
                qclient: qclient,
                baseURL: releaseBaseURL,
                startedAt: startedAt,
                progress: progress
            )
        }.value
        return PreparedFirstInstallationAssets(
            nodeRelease: node,
            qclientRelease: qclient,
            manifestURL: manifestURL
        )
    }

    static func stageQClient(
        for preflight: InstallationPreflight,
        startedAt: Date,
        progress: @escaping @Sendable (NodeUpdateProgress) -> Void
    ) async throws -> PreparedQClientAsset {
        if preflight.installedNodeBuild?.kind == .source,
            let installedBuild = preflight.installedNodeBuild
        {
            let manifestURL = try await Task.detached(priority: .utility) {
                try ReleaseChecker.stageMatchingSourceQClient(
                    installed: installedBuild,
                    repositoryURL: repositoryURL,
                    startedAt: startedAt,
                    progress: progress
                )
            }.value
            return PreparedQClientAsset(officialRelease: nil, manifestURL: manifestURL)
        }

        let release = try await ReleaseChecker.fetchSignedQClientRelease(endpoint: qclientReleaseURL)
        let manifestURL = try await Task.detached(priority: .utility) {
            try ReleaseChecker.stageQClientRelease(
                release,
                baseURL: releaseBaseURL,
                startedAt: startedAt,
                progress: progress
            )
        }.value
        return PreparedQClientAsset(officialRelease: release, manifestURL: manifestURL)
    }
}
