import Foundation

/// The only official executable kinds accepted by QuilNode's privileged
/// installation boundary. Keeping this vocabulary closed prevents a staged
/// manifest from turning the service into a generic root installer.
public enum OfficialSignedArtifactKind: String, Codable, Sendable {
    case node
    case qclient
}

public enum ArtifactTrustKind: String, Codable, Sendable {
    case officialSigned
    case pinnedSource
}

/// Immutable evidence for one already-staged Quilibrium artifact. Signed
/// releases carry their quorum; explicitly selected source channels carry the
/// exact official-repository commit and never claim release signatures.
public struct SignedArtifactActivation: Codable, Equatable, Sendable {
    public var kind: OfficialSignedArtifactKind
    public var trust: ArtifactTrustKind
    public var releaseVersion: String
    public var reportedVersion: String?
    public var binaryFileName: String
    public var sha256: String
    public var signatureIndices: [Int]
    public var branch: String?
    public var commit: String?

    public init(
        kind: OfficialSignedArtifactKind,
        trust: ArtifactTrustKind = .officialSigned,
        releaseVersion: String,
        reportedVersion: String? = nil,
        binaryFileName: String,
        sha256: String,
        signatureIndices: [Int],
        branch: String? = nil,
        commit: String? = nil
    ) {
        self.kind = kind
        self.trust = trust
        self.releaseVersion = releaseVersion
        self.reportedVersion = reportedVersion
        self.binaryFileName = binaryFileName
        self.sha256 = sha256
        self.signatureIndices = signatureIndices
        self.branch = branch
        self.commit = commit
    }
}

/// Atomic first-install input. A production installation is not ready unless
/// both the node and qclient have an independently verified official bundle.
public struct FirstInstallActivationManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var createdAt: Date
    public var node: SignedArtifactActivation
    public var qclient: SignedArtifactActivation

    public init(
        createdAt: Date = Date(),
        node: SignedArtifactActivation,
        qclient: SignedArtifactActivation
    ) {
        schemaVersion = 1
        self.createdAt = createdAt
        self.node = node
        self.qclient = qclient
    }
}

/// Standalone qclient lifecycle input used for existing-node adoption and
/// qclient-only repair/update operations. The enclosed artifact carries its
/// own trust kind, so a signed client and an exact-commit source client cannot
/// be confused at the privileged boundary.
public struct QClientActivationManifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var createdAt: Date
    public var qclient: SignedArtifactActivation

    public init(createdAt: Date = Date(), qclient: SignedArtifactActivation) {
        schemaVersion = 1
        self.createdAt = createdAt
        self.qclient = qclient
    }
}
