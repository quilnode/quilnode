import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct ActivationManifest: Codable {
    var schemaVersion: Int
    var channel: String
    var version: String
    var reportedVersion: String?
    var branch: String?
    var commit: String?
    var binaryFileName: String
    var sha256: String
    var createdAt: Date
    var signatureIndices: [Int]
    var qclient: SignedArtifactActivation?
}

struct RollbackManifest: Codable {
    var binaryTarget: String
    var sidecarTargets: [String: String]
    var signatureCheck: Bool
    var createdAt: Date
}
