import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func walletInventory() throws -> WalletInventoryPayload {
        let activeDirectory = nodeDirectory.appendingPathComponent(".config", isDirectory: true)
        let activeInspection = try inspectKeyset(activeDirectory)
        let registry = try loadWalletRegistry()
        // Inventory must remain a fast filesystem transaction. Public IDs are
        // enriched by the app through the existing node-info endpoint so a
        // slow CLI probe never hides the detected active keyset at launch.
        let activeIdentity = emptyWalletIdentity()
        var keysets: [ManagedKeysetPayload] = []

        for profile in registry.profiles {
            let directory = walletProfiles.appendingPathComponent(profile.directoryName, isDirectory: true)
            guard FileManager.default.fileExists(atPath: directory.path) else { continue }
            let inspection = try inspectKeyset(directory)
            let isActive = registry.activeKeysetID == profile.id
            keysets.append(
                payload(
                    profile: profile,
                    inspection: isActive ? activeInspection : inspection,
                    isActive: isActive,
                    identities: isActive ? activeIdentity : emptyWalletIdentity(),
                    managed: true
                ))
        }

        if registry.profiles.isEmpty || registry.activeKeysetID == nil {
            let syntheticID = stableUUID(from: activeInspection.fingerprint)
            keysets.insert(
                ManagedKeysetPayload(
                    id: syntheticID,
                    name: "Current node identity",
                    format: activeInspection.format,
                    health: activeInspection.health,
                    isActive: true,
                    isManaged: false,
                    requiresMigration: activeInspection.requiresMigration,
                    keyCount: activeInspection.keyCount,
                    keyTypes: activeInspection.keyTypes,
                    identities: activeIdentity,
                    sourceLabel: "Existing /opt/quilibrium/node/.config",
                    createdAt: nil,
                    importedAt: nil,
                    lastActivatedAt: nil,
                    lastVerifiedBackupAt: nil,
                    lastExternalBackupAt: nil,
                    automaticRecoveryCopies: recoveryCopyCount(for: syntheticID),
                    fingerprint: activeInspection.fingerprint,
                    warnings: activeInspection.warnings
                ),
                at: 0
            )
        }

        return WalletInventoryPayload(
            keysets: keysets,
            activeKeysetID: registry.activeKeysetID ?? keysets.first(where: { $0.isActive })?.id,
            serviceSupportsTransactions: true,
            recoveryVaultHealthy: walletVaultIsHealthy(),
            message: keysets.first(where: { $0.isActive })?.isManaged == true
                ? "The active identity is protected by transactional recovery copies."
                : "Adopt the existing identity to create its first verified recovery copy."
        )
    }

    static func payload(
        profile: StoredWalletProfile,
        inspection: KeysetInspectionPayload,
        isActive: Bool,
        identities: WalletPublicIdentityPayload,
        managed: Bool
    ) -> ManagedKeysetPayload {
        ManagedKeysetPayload(
            id: profile.id,
            name: profile.name,
            format: inspection.format,
            health: inspection.health,
            isActive: isActive,
            isManaged: managed,
            requiresMigration: inspection.requiresMigration,
            keyCount: inspection.keyCount,
            keyTypes: inspection.keyTypes,
            identities: identities,
            sourceLabel: profile.sourceLabel,
            createdAt: profile.createdAt,
            importedAt: profile.importedAt,
            lastActivatedAt: profile.lastActivatedAt,
            lastVerifiedBackupAt: profile.lastVerifiedBackupAt,
            lastExternalBackupAt: profile.lastExternalBackupAt,
            automaticRecoveryCopies: recoveryCopyCount(for: profile.id),
            fingerprint: inspection.fingerprint,
            warnings: inspection.warnings
        )
    }
}
