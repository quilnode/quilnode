import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct ManagedQClientRecord: Codable {
    var schemaVersion = 1
    var releaseVersion: String
    var trust: ArtifactTrustKind
    var reportedVersion: String
    var binaryFileName: String
    var sha256: String
    var signatureIndices: [Int]
    var branch: String?
    var commit: String?
    var installedAt: Date
}

struct ServiceQClientStatus: Codable {
    enum State: String, Codable { case missing, verified, invalid }
    var state: State
    var releaseVersion: String?
    var reportedVersion: String?
    var binaryFileName: String?
    var trust: ArtifactTrustKind?
    var commit: String?
    var sha256: String?
    var signatureCount: Int
    var installedAt: Date?
    var detail: String
}
