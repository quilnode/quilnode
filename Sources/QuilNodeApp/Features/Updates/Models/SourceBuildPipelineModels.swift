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
    let workspace: URL
    let repository: URL
    let buildScript: URL
    let sourceVersion: String
    let displayVersion: String
    let seniorityDataset: GitLFSPointer
    let logURL: URL
    let sandbox: PreparedSourceBuildSandbox
}

struct StagedSourceNodeArtifact {
    let url: URL
    let fileName: String
    let sha256: String
}
