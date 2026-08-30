import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension OperatorInterlockPresentation {
    struct UpdateChannelCopy {
        let outcome: String
        let symbol: String
        let tone: OperatorInterlockTone
        let observeDetail: String
        let verifyDetail: String
        let scopeDetail: String
        let verification: [String]
        let trustNote: String
    }

    static func updateChannel(for policy: NodeUpdatePolicy) -> UpdateChannelCopy {
        switch policy {
        case .manual:
            return .init(
                outcome: "Keep all node runtime updates under explicit operator control.",
                symbol: "hand.raised.fill",
                tone: .accent,
                observeDetail: "No automatic channel is polled.",
                verifyDetail: "Every future install stays manual.",
                scopeDetail: "explicit operator requests",
                verification: ["Automatic schedule disabled", "Current runtime retained"],
                trustNote:
                    "This disables scheduling and revokes passwordless source activation. Manual source installs still require explicit approval."
            )
        case .signedStable:
            return .init(
                outcome: "Follow only strictly newer official releases that pass digest and Ed448 quorum verification.",
                symbol: "checkmark.seal.fill",
                tone: .success,
                observeDetail: "Read the official signed release channel.",
                verifyDetail: "Require SHA3-256 and the seven-signature quorum.",
                scopeDetail: "strictly newer signed releases",
                verification: ["Release is newer", "Digest matches", "Signature quorum passes", "Rollback retained"],
                trustNote:
                    "The authorized local service installs only quorum-signed releases and never automatically downgrades the installed runtime."
            )
        case .approvedDevelopment:
            return .init(
                outcome: "Follow only the exact commit approved by the subpatch marker on the highest version branch.",
                symbol: "checkmark.shield.fill",
                tone: .information,
                observeDetail: "Track the highest official version branch.",
                verifyDetail: "Bind the root subpatch marker to one exact commit.",
                scopeDetail: "marker-approved development commits",
                verification: [
                    "Highest version branch", "Marker commit bound", "Automatic activation authorized",
                    "Rollback retained",
                ],
                trustNote:
                    "The existing local service may activate marker-approved builds without asking macOS again. Later unmarked commits, raw commits, identity changes, and recovery exports remain outside this permission."
            )
        case .bleedingEdge:
            return .init(
                outcome:
                    "Follow the newest raw commit across official branches, including potentially unfinished work.",
                symbol: "exclamationmark.triangle.fill",
                tone: .warning,
                observeDetail: "Track the newest official repository commit.",
                verifyDetail: "Build the exact commit locally; no approval marker is required.",
                scopeDetail: "the newest raw official commit",
                verification: [
                    "Commit resolved", "Local build succeeds", "Automatic activation authorized", "Rollback retained",
                ],
                trustNote:
                    "Raw development is intentionally high risk. This explicit selection permits the authenticated local service to activate raw official commits without repeated passwords."
            )
        }
    }
}
