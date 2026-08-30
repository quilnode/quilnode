import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum RecoveryLayer: String, CaseIterable, Identifiable {
    case activePackage
    case automaticRollback
    case separateBackup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activePackage: "Active identity package"
        case .automaticRollback: "Automatic rollback"
        case .separateBackup: "Separate backup"
        }
    }

    var symbol: String {
        switch self {
        case .activePackage: "checkmark.shield.fill"
        case .automaticRollback: "clock.arrow.circlepath"
        case .separateBackup: "externaldrive.badge.checkmark"
        }
    }
}

enum RecoveryLayerState: Equatable {
    case verified
    case review
    case recommended

    var label: String {
        switch self {
        case .verified: "Verified"
        case .review: "Review"
        case .recommended: "Recommended"
        }
    }
}

struct RecoveryLayerPresentation: Identifiable {
    let layer: RecoveryLayer
    let state: RecoveryLayerState
    let value: String
    let detail: String
    let privacyField: PrivacyField?

    var id: RecoveryLayer { layer }
}

struct RecoveryRecommendation {
    enum Kind: Equatable {
        case addIdentity
        case protectActive
        case createSeparateBackup
        case maintainCoverage
    }

    let kind: Kind
    let title: String
    let detail: String
    let actionTitle: String
}

struct RecoveryWorkspacePresentation {
    let readinessTitle: String
    let readinessDetail: String
    let stages: [RecoveryLayerPresentation]
    let recommendation: RecoveryRecommendation
    let storedIdentityCount: Int

    static func make(inventory: WalletInventory) -> RecoveryWorkspacePresentation {
        guard let active = inventory.activeKeyset else {
            return RecoveryWorkspacePresentation(
                readinessTitle: "Identity setup required",
                readinessDetail: "Create or import one complete config.yml and keys.yml package.",
                stages: [
                    RecoveryLayerPresentation(
                        layer: .activePackage,
                        state: .review,
                        value: "Not found",
                        detail: "No active complete package is registered.",
                        privacyField: nil
                    ),
                    RecoveryLayerPresentation(
                        layer: .automaticRollback,
                        state: .review,
                        value: "Unavailable",
                        detail: "Rollback protection begins after an identity is adopted or activated.",
                        privacyField: nil
                    ),
                    RecoveryLayerPresentation(
                        layer: .separateBackup,
                        state: .recommended,
                        value: "Unavailable",
                        detail: "Add an identity before exporting a separate copy.",
                        privacyField: nil
                    ),
                ],
                recommendation: RecoveryRecommendation(
                    kind: .addIdentity,
                    title: "Add a complete identity",
                    detail: "Create a new package or import the complete config.yml and keys.yml pair.",
                    actionTitle: "Add identity"
                ),
                storedIdentityCount: inventory.keysets.count
            )
        }

        let packageReady = active.health == .ready
        let rollbackReady = active.automaticRecoveryCopies > 0
        let separateReady = active.lastExternalBackupAt != nil
        let readinessTitle: String
        let readinessDetail: String

        if !active.isManaged {
            readinessTitle = "Protect the active identity"
            readinessDetail = "Adopt the complete package into the secure local recovery service."
        } else if !packageReady {
            readinessTitle = "Identity package needs review"
            readinessDetail = "Resolve the package health or migration warning before relying on recovery."
        } else if !rollbackReady {
            readinessTitle = "Rollback evidence is missing"
            readinessDetail = "A separate backup still protects against loss of this Mac."
        } else if !separateReady {
            readinessTitle = "Separate backup recommended"
            readinessDetail = "Local rollback exists; add a verified copy on storage you control."
        } else {
            readinessTitle = "Recovery layers verified"
            readinessDetail = "The active package has local rollback and a recorded separate backup."
        }

        return RecoveryWorkspacePresentation(
            readinessTitle: readinessTitle,
            readinessDetail: readinessDetail,
            stages: [
                RecoveryLayerPresentation(
                    layer: .activePackage,
                    state: packageReady && active.isManaged ? .verified : .review,
                    value: packageReady ? active.format.label : active.health.label,
                    detail: active.isManaged
                        ? "The complete package is managed by the local recovery service."
                        : "Adopt this running identity before relying on managed recovery.",
                    privacyField: nil
                ),
                RecoveryLayerPresentation(
                    layer: .automaticRollback,
                    state: rollbackReady ? .verified : .review,
                    value: rollbackReady
                        ? "\(active.automaticRecoveryCopies) verified snapshot\(active.automaticRecoveryCopies == 1 ? "" : "s")"
                        : "Not verified",
                    detail: "Used automatically if a protected identity switch cannot be validated.",
                    privacyField: rollbackReady ? .recoveryMetadata : nil
                ),
                RecoveryLayerPresentation(
                    layer: .separateBackup,
                    state: separateReady ? .verified : .recommended,
                    value: active.lastExternalBackupAt.map {
                        "Verified \($0.formatted(date: .abbreviated, time: .shortened))"
                    } ?? "Not recorded",
                    detail: separateReady
                        ? "A successful export to operator-selected storage is recorded."
                        : "Choose an encrypted drive, disk image, or protected vault you control.",
                    privacyField: separateReady ? .localTimestamp : nil
                ),
            ],
            recommendation: recommendation(active),
            storedIdentityCount: inventory.keysets.count
        )
    }

    private static func recommendation(_ active: ManagedKeyset) -> RecoveryRecommendation {
        if !active.isManaged {
            return RecoveryRecommendation(
                kind: .protectActive,
                title: "Protect the active identity",
                detail: "Create managed rollback protection before changing this identity.",
                actionTitle: "Protect identity"
            )
        }
        if active.lastExternalBackupAt == nil {
            return RecoveryRecommendation(
                kind: .createSeparateBackup,
                title: "Create a separate verified backup",
                detail: "Export the complete config.yml and keys.yml pair to protected storage you control.",
                actionTitle: "Create backup"
            )
        }
        return RecoveryRecommendation(
            kind: .maintainCoverage,
            title: "Recovery coverage is recorded",
            detail: "Keep at least one verified copy separate from this Mac and replace stale media when needed.",
            actionTitle: "Create another copy"
        )
    }
}

extension KeysetHealth {
    fileprivate var label: String {
        switch self {
        case .ready: "Ready"
        case .migrationRequired: "Migration required"
        case .incomplete: "Incomplete"
        case .invalid: "Invalid"
        }
    }
}
