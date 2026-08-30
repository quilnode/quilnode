import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum UpdateChannelKind: String, CaseIterable, Identifiable, Sendable {
    case signed
    case approved
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signed: "Signed Stable"
        case .approved: "Approved Development"
        case .raw: "Raw Development"
        }
    }

    var subtitle: String {
        switch self {
        case .signed: "Official multi-signature release"
        case .approved: "Exact commit carrying the subpatch marker"
        case .raw: "Newest official branch head"
        }
    }

    var systemImage: String {
        switch self {
        case .signed: "checkmark.shield.fill"
        case .approved: "checkmark.seal.fill"
        case .raw: "hammer.fill"
        }
    }
}

enum UpdateChannelAssurance: Equatable, Sendable {
    case highest
    case approved
    case experimental

    var title: String {
        switch self {
        case .highest: "Highest"
        case .approved: "Approved"
        case .experimental: "Experimental"
        }
    }

    var detail: String {
        switch self {
        case .highest: "Digest + signature quorum"
        case .approved: "Repository marker pinned"
        case .experimental: "Unapproved source head"
        }
    }
}

enum UpdateChannelState: Equatable, Sendable {
    case current
    case ready
    case ahead(Int?)
    case installedAhead
    case unavailable

    var title: String {
        switch self {
        case .current: "Current"
        case .ready: "Ready"
        case let .ahead(count): count.map { "+\($0) commits" } ?? "Newer source"
        case .installedAhead: "Installed ahead"
        case .unavailable: "Unavailable"
        }
    }
}

struct UpdateChannelPresentation: Identifiable, Sendable {
    var id: UpdateChannelKind { kind }
    var kind: UpdateChannelKind
    var assurance: UpdateChannelAssurance
    var version: String
    var commit: String?
    var evidence: String
    var discoveredAt: Date?
    var state: UpdateChannelState
    var action: UpdateActionAvailability
    var actionTitle: String

    static func make(
        snapshot: UpdateCenterSnapshot,
        isInstalling: Bool,
        hasStagedUpdate: Bool
    ) -> [Self] {
        [
            signed(snapshot, isInstalling: isInstalling, hasStagedUpdate: hasStagedUpdate),
            approved(snapshot, isInstalling: isInstalling, hasStagedUpdate: hasStagedUpdate),
            raw(snapshot, isInstalling: isInstalling, hasStagedUpdate: hasStagedUpdate),
        ]
    }

    private static func signed(
        _ snapshot: UpdateCenterSnapshot,
        isInstalling: Bool,
        hasStagedUpdate: Bool
    ) -> Self {
        let versionRelation = versionRelation(snapshot.signed.version, installed: snapshot.installed.build.version)
        let channelState: UpdateChannelState
        switch versionRelation {
        case .newer: channelState = .ready
        case .same: channelState = .current
        case .older: channelState = .installedAhead
        }
        return Self(
            kind: .signed,
            assurance: .highest,
            version: snapshot.signed.version,
            commit: nil,
            evidence: "\(snapshot.signed.signatureIndices.count)/17 signatures",
            discoveredAt: snapshot.signed.manifestModifiedAt,
            state: channelState,
            action: availability(
                isCandidateNewer: versionRelation == .newer,
                currentMessage: versionRelation == .older
                    ? "The installed runtime is newer than the signed channel; no downgrade is offered."
                    : "The newest signed release is already installed.",
                isInstalling: isInstalling,
                hasStagedUpdate: hasStagedUpdate
            ),
            actionTitle: "Install signed"
        )
    }

    private static func approved(
        _ snapshot: UpdateCenterSnapshot,
        isInstalling: Bool,
        hasStagedUpdate: Bool
    ) -> Self {
        guard let release = snapshot.source.approvedDevelopment else {
            return Self(
                kind: .approved,
                assurance: .approved,
                version: "Waiting for marker",
                commit: nil,
                evidence: snapshot.source.approvalIssue ?? "No valid subpatch marker",
                discoveredAt: nil,
                state: .unavailable,
                action: .blocked("Waiting for an official subpatch approval marker."),
                actionTitle: "Build approved"
            )
        }

        let installedMatches = commitMatches(release.commit, installed: snapshot.installed.build.commit)
        let newer = isNewer(release.version, than: snapshot.installed.build.version)
        let action: UpdateActionAvailability
        if installedMatches {
            action = .current("This exact approved commit is already installed.")
        } else {
            action = availability(
                isCandidateNewer: newer,
                currentMessage: "The approved version is not newer than the installed build.",
                isInstalling: isInstalling,
                hasStagedUpdate: hasStagedUpdate
            )
        }
        return Self(
            kind: .approved,
            assurance: .approved,
            version: release.version,
            commit: release.commit,
            evidence: "subpatch \(release.subpatch) · \(release.branch)",
            discoveredAt: release.committedAt,
            state: installedMatches ? .current : .ahead(release.unapprovedCommitsAhead),
            action: action,
            actionTitle: "Build & install approved"
        )
    }

    private static func raw(
        _ snapshot: UpdateCenterSnapshot,
        isInstalling: Bool,
        hasStagedUpdate: Bool
    ) -> Self {
        let head = snapshot.source.newestAnyBranch
        let installedMatches = commitMatches(head.commit, installed: snapshot.installed.build.commit)
        let action: UpdateActionAvailability
        if installedMatches {
            action = .current("This exact source commit is already installed.")
        } else if isInstalling {
            action = .blocked("Another node update is running.")
        } else if hasStagedUpdate {
            action = .blocked("Resolve the staged update first.")
        } else {
            action = .ready("Build the newest official branch head without an approval guarantee.")
        }
        return Self(
            kind: .raw,
            assurance: .experimental,
            version: head.name,
            commit: head.commit,
            evidence: head.subject,
            discoveredAt: head.committedAt,
            state: installedMatches ? .current : .ahead(snapshot.source.commitsBehind),
            action: action,
            actionTitle: "Build & install raw"
        )
    }

    private static func availability(
        isCandidateNewer: Bool,
        currentMessage: String,
        isInstalling: Bool,
        hasStagedUpdate: Bool
    ) -> UpdateActionAvailability {
        guard isCandidateNewer else { return .current(currentMessage) }
        if isInstalling { return .blocked("Another node update is running.") }
        if hasStagedUpdate { return .blocked("Resolve the staged update first.") }
        return .ready("The candidate can be prepared while the current node remains online.")
    }

    private static func commitMatches(_ candidate: String, installed: String?) -> Bool {
        guard let installed else { return false }
        return candidate.hasPrefix(installed) || installed.hasPrefix(candidate)
    }

    private static func isNewer(_ candidate: String, than installed: String?) -> Bool {
        guard let candidateVersion = NodeVersion(candidate) else { return false }
        guard let installed, let installedVersion = NodeVersion(installed) else { return true }
        return installedVersion < candidateVersion
    }

    private enum VersionRelation {
        case older
        case same
        case newer
    }

    private static func versionRelation(_ candidate: String, installed: String?) -> VersionRelation {
        guard let candidateVersion = NodeVersion(candidate) else { return .same }
        guard let installed, let installedVersion = NodeVersion(installed) else { return .newer }
        if installedVersion < candidateVersion { return .newer }
        if candidateVersion < installedVersion { return .older }
        return .same
    }
}
