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

    static func updatePolicy(_ policy: NodeUpdatePolicy) -> OperatorInterlockModel {
        let channel = updateChannel(for: policy)
        return OperatorInterlockModel(
            id: "update-policy-\(policy.rawValue)",
            eyebrow: "UPDATE TRUST POLICY",
            title: "Enable \(policy.title) updates",
            outcome: channel.outcome,
            symbol: channel.symbol,
            tone: channel.tone,
            steps: [
                .init(
                    id: "observe", title: "Observe channel", detail: channel.observeDetail,
                    symbol: "antenna.radiowaves.left.and.right", tone: .information),
                .init(
                    id: "verify", title: "Verify candidate", detail: channel.verifyDetail,
                    symbol: "checkmark.shield.fill", tone: channel.tone),
                .init(
                    id: "activate", title: "Guarded activation",
                    detail: "Stage first, retain rollback, then restart the node.",
                    symbol: "arrow.triangle.2.circlepath", tone: .success),
            ],
            changes: [
                .init(
                    id: "policy", title: "Automatic policy",
                    detail: "The schedule and root-owned activation permission follow only \(channel.scopeDetail).",
                    symbol: "clock.badge.checkmark"),
                .init(
                    id: "runtime", title: "Managed runtime",
                    detail: "A qualifying candidate may replace the node binary after preparation succeeds.",
                    symbol: "shippingbox.fill"),
            ],
            preserved: standardNodeBoundary + [
                .init(
                    id: "rollback", title: "Previous runtime",
                    detail: "The installed binary remains active until activation and is retained for rollback.",
                    symbol: "arrow.uturn.backward.circle.fill")
            ],
            verification: channel.verification,
            trustNote: channel.trustNote,
            decisions: updateDecisions,
            defaultDecisionID: "now",
            cancelTitle: "Cancel"
        )
    }

    private static let updateDecisions: [OperatorInterlockDecision] = [
        .init(
            id: "now", title: "Enable and check now",
            detail: "Save the policy, then inspect the selected channel immediately.",
            actionTitle: "Enable & check now", symbol: "bolt.fill", tone: .information,
            bullets: ["Starts one check now", "Keeps the six-hour schedule"]),
        .init(
            id: "later", title: "Enable for later",
            detail: "Save the policy without starting a foreground check.",
            actionTitle: "Enable for later", symbol: "clock.fill", tone: .accent,
            bullets: ["No check starts now", "Runs on the six-hour schedule"]),
    ]
}
