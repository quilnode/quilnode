import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct UpdateSignalBaseline: Codable, Equatable, Sendable {
    var policy: NodeUpdatePolicy
    var fingerprint: String
    var entityTag: String?
    var observedAt: Date
}

struct UpdateSignalProbe: Equatable, Sendable {
    enum Result: Equatable, Sendable {
        case unchanged
        case changed
    }

    var result: Result
    var fingerprint: String
    var entityTag: String?
}

extension ReleaseChecker.AutomaticCandidate {
    var identifier: String {
        switch self {
        case let .signed(release): "signed:\(release.version)"
        case let .approvedDevelopment(release): "approved:\(release.commit)"
        case let .rawDevelopment(head): "raw:\(head.commit)"
        }
    }

    var notificationChannel: String {
        switch self {
        case .signed: "Signed Stable"
        case .approvedDevelopment: "Approved Development"
        case .rawDevelopment: "Raw Development"
        }
    }

    var notificationVersion: String {
        switch self {
        case let .signed(release): release.version
        case let .approvedDevelopment(release): release.version
        case let .rawDevelopment(head): head.name
        }
    }
}
