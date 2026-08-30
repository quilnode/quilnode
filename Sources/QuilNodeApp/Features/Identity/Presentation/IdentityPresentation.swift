import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum IdentityRole: String, CaseIterable, Identifiable {
    case networkPeer
    case seniority
    case prover
    case quilAccount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .networkPeer: "Network peer"
        case .seniority: "Seniority identity"
        case .prover: "Prover address"
        case .quilAccount: "QUIL account"
        }
    }

    var shortTitle: String {
        switch self {
        case .networkPeer: "Peer"
        case .seniority: "Seniority"
        case .prover: "Prover"
        case .quilAccount: "Account"
        }
    }

    var detail: String {
        switch self {
        case .networkPeer: "Current mesh identity"
        case .seniority: "Legacy Ed448 history root"
        case .prover: "Proof and allocation identity"
        case .quilAccount: "Spendable token account"
        }
    }

    var layer: String {
        switch self {
        case .networkPeer: "Transport layer"
        case .seniority: "History layer"
        case .prover: "Proving layer"
        case .quilAccount: "Account layer"
        }
    }

    var symbol: String {
        switch self {
        case .networkPeer: "network"
        case .seniority: "clock.arrow.circlepath"
        case .prover: "checkmark.seal"
        case .quilAccount: "wallet.bifold"
        }
    }

    var explanationTitle: String {
        switch self {
        case .networkPeer: "Why this is the transport identity"
        case .seniority: "Why this differs from the network peer"
        case .prover: "Why this differs from the seniority identity"
        case .quilAccount: "Why this differs from the prover address"
        }
    }

    var explanation: String {
        switch self {
        case .networkPeer:
            "The network peer identifies the current transport session used to connect to the mesh. It can differ from the legacy identity that carries historical seniority."
        case .seniority:
            "The network peer connects this node to the mesh. The legacy Ed448 identity is the history root the consensus registry uses when it reports chain seniority and merge history."
        case .prover:
            "The prover address identifies proof and allocation activity. It is a separate public role from the legacy identity used to report historical seniority."
        case .quilAccount:
            "The QUIL account is the spendable token account returned by the local client. It is separate from the identity used for proof and allocation activity."
        }
    }
}

struct IdentityRolePresentation: Identifiable {
    let kind: IdentityRole
    let value: String?
    let evidenceSource: String
    let evidenceKind: String
    let observedAt: Date?
    let externalURL: URL?

    var id: IdentityRole { kind }
    var displayedValue: String { value ?? "Not available" }
    var privacyField: PrivacyField? { value == nil ? nil : .networkIdentifier }
    var isAvailable: Bool { value?.isEmpty == false }
}

struct IdentityParticipationPresentation {
    enum State {
        case offline
        case awaitingAllocation
        case joining
        case allocated
        case active
    }

    let state: State
    let title: String
    let detail: String
    let symbol: String
}

struct IdentityWorkspacePresentation {
    let participation: IdentityParticipationPresentation
    let seniority: Int64
    let seniorityTrend: SeniorityTrend
    let totalAllocations: Int
    let activeShards: Int
    let pendingJoins: Int
    let balance: String?
    let chainEvidenceSource: String
    let chainEvidenceAt: Date?
    let roles: [IdentityRolePresentation]

    func role(_ kind: IdentityRole) -> IdentityRolePresentation {
        roles.first(where: { $0.kind == kind })
            ?? IdentityRolePresentation(
                kind: kind,
                value: nil,
                evidenceSource: "Local node",
                evidenceKind: "Unavailable",
                observedAt: nil,
                externalURL: nil
            )
    }

    static func make(
        snapshot: NodeSnapshot,
        seniorityTrend: SeniorityTrend
    ) -> IdentityWorkspacePresentation {
        let senioritySource = sourceLabel(snapshot.seniorityEvidenceSource)
        let seniorityKind = evidenceKindLabel(snapshot.seniorityEvidenceKind)
        let nodeObservedAt = snapshot.metricsUpdatedAt ?? snapshot.collectedAt

        return IdentityWorkspacePresentation(
            participation: participation(snapshot),
            seniority: snapshot.seniority,
            seniorityTrend: seniorityTrend,
            totalAllocations: snapshot.totalAllocations,
            activeShards: snapshot.activeShards,
            pendingJoins: snapshot.pendingJoins,
            balance: snapshot.quilBalance,
            chainEvidenceSource: senioritySource,
            chainEvidenceAt: snapshot.seniorityUpdatedAt,
            roles: [
                IdentityRolePresentation(
                    kind: .networkPeer,
                    value: snapshot.peerID,
                    evidenceSource: "Local node",
                    evidenceKind: "Transport identity",
                    observedAt: nodeObservedAt,
                    externalURL: IdentityExplorerLink.peer(snapshot.peerID)
                ),
                IdentityRolePresentation(
                    kind: .seniority,
                    value: snapshot.legacyPeerID,
                    evidenceSource: senioritySource,
                    evidenceKind: seniorityKind,
                    observedAt: snapshot.seniorityUpdatedAt,
                    externalURL: IdentityExplorerLink.peer(snapshot.legacyPeerID)
                ),
                IdentityRolePresentation(
                    kind: .prover,
                    value: snapshot.proverAddress,
                    evidenceSource: "Local node",
                    evidenceKind: "Proof identity",
                    observedAt: snapshot.proverStatusUpdatedAt ?? nodeObservedAt,
                    externalURL: IdentityExplorerLink.prover(snapshot.proverAddress)
                ),
                IdentityRolePresentation(
                    kind: .quilAccount,
                    value: snapshot.quilAccount,
                    evidenceSource: "Local QClient",
                    evidenceKind: "Spendable account",
                    observedAt: snapshot.balanceUpdatedAt,
                    externalURL: nil
                ),
            ]
        )
    }

    private static func participation(_ snapshot: NodeSnapshot) -> IdentityParticipationPresentation {
        let evidence = ParticipationEvidencePresentation.make(snapshot: snapshot)
        let state: IdentityParticipationPresentation.State =
            switch evidence.state {
            case .offline: .offline
            case .networkRecovery, .allocated: .allocated
            case .activeAllocations: .active
            case .joining: .joining
            case .awaitingAllocation: .awaitingAllocation
            }
        return IdentityParticipationPresentation(
            state: state,
            title: evidence.title,
            detail: evidence.detail,
            symbol: evidence.systemImage
        )
    }

    private static func sourceLabel(_ source: SeniorityEvidenceSource?) -> String {
        switch source {
        case .consensusRegistry: "Chain registry"
        case .nodeDiagnostic: "Node diagnostic"
        case nil: "Local node"
        }
    }

    private static func evidenceKindLabel(_ kind: SeniorityEvidenceKind?) -> String {
        switch kind {
        case .registrySnapshot: "Registry snapshot"
        case .valueChanged: "Registry value changed"
        case .diagnostic: "Diagnostic value"
        case nil: "Evidence pending"
        }
    }
}

enum IdentityExplorerLink {
    static func peer(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        return URL(string: "https://quilscan.com/peer")?.appendingPathComponent(value)
    }

    static func prover(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        var components = URLComponents(string: "https://quilscan.com/rings")
        components?.queryItems = [URLQueryItem(name: "prover", value: value)]
        return components?.url
    }
}

enum IdentityBalanceFormatter {
    static func compact(_ value: String) -> String {
        let trimmed = value.compactDecimal
        guard trimmed.count > 10, let number = Double(trimmed), number.isFinite else {
            return trimmed
        }
        guard number != 0 else { return "0" }

        if abs(number) < 0.0001 || abs(number) >= 1_000_000_000 {
            return String(format: "%.3e", locale: Locale(identifier: "en_US_POSIX"), number)
                .lowercased()
        }
        return String(format: "%.7g", locale: Locale(identifier: "en_US_POSIX"), number)
    }
}
