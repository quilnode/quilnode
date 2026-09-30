import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct SourceBuildPipelineContext {
    let head: GitBranchHead
    let repositoryURL: String
    let startedAt: Date
    let channel: String
    let directory: URL
    let repository: URL
    let sourceVersion: String
    let displayVersion: String
    let seniorityDataset: GitLFSPointer
    let logURL: URL
    let sandbox: PreparedSourceBuildSandbox
    let dependencyLock: SourceBuildDependencyLock
}

struct SourceBuildDependencyLock: Codable, Sendable {
    let upstreamSHA256: String
    let resolvedSHA256: String

    var wasRepaired: Bool { upstreamSHA256 != resolvedSHA256 }
}

struct StagedSourceNodeArtifact {
    let url: URL
    let fileName: String
    let sha256: String
}
