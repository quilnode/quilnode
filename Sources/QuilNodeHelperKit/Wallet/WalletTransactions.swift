import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func performWalletTransaction(
        _ manifest: WalletTransactionManifest,
        configuration: ServiceConfiguration
    ) throws -> String {
        let manifestAge = Date().timeIntervalSince(manifest.createdAt)
        guard manifest.schemaVersion == 2,
            manifestAge >= -300,
            manifestAge < 24 * 60 * 60,
            manifest.confirmedBackupResponsibility,
            validWalletName(manifest.displayName)
        else { throw HelperFailure.invalidManifest("wallet transaction consent, name, date, or schema is invalid") }

        try prepareWalletVault()
        switch manifest.kind {
        case .adoptActive:
            var registry = try loadWalletRegistry()
            let active = nodeDirectory.appendingPathComponent(".config", isDirectory: true)
            let inspection = try inspectKeyset(active)
            guard inspection.health != "invalid", inspection.health != "incomplete" else {
                throw HelperFailure.service("the active keyset is not complete enough to adopt")
            }
            let id = stableUUID(from: inspection.fingerprint)
            if registry.profiles.contains(where: { $0.id == id }) {
                registry.activeKeysetID = id
                try saveWalletRegistry(registry)
                return "The active identity is already managed and verified."
            }
            let backupDate = try createRecoveryCopy(from: active, keysetID: id, reason: "adopt")
            let directoryName = id.uuidString.lowercased()
            let profileDirectory = walletProfiles.appendingPathComponent(directoryName, isDirectory: true)
            try replaceKeysetFiles(from: active, to: profileDirectory)
            registry.profiles.append(
                .init(
                    id: id,
                    name: manifest.displayName,
                    sourceLabel: "Adopted from the existing node",
                    directoryName: directoryName,
                    createdAt: nil,
                    importedAt: Date(),
                    lastActivatedAt: Date(),
                    lastVerifiedBackupAt: backupDate
                ))
            registry.activeKeysetID = id
            try saveWalletRegistry(registry)
            return "Existing identity adopted. A hash-verified recovery copy was created before management began."

        case .importKeyset:
            guard let selected = manifest.selectedDirectory else {
                throw HelperFailure.invalidManifest("the selected import directory is missing")
            }
            let source = try validateOperatorSelectedDirectory(
                selected,
                configuration: configuration,
                purpose: .keysetSource
            )
            let inspection = try inspectKeyset(source)
            guard inspection.health != "invalid", inspection.health != "incomplete" else {
                throw HelperFailure.service(inspection.warnings.joined(separator: " "))
            }
            var registry = try loadWalletRegistry()
            let id = manifest.keysetID ?? UUID()
            guard
                !registry.profiles.contains(where: {
                    $0.id == id || $0.name.caseInsensitiveCompare(manifest.displayName) == .orderedSame
                })
            else {
                throw HelperFailure.service("an identity package with this name or identifier already exists")
            }
            let directoryName = id.uuidString.lowercased()
            let destination = walletProfiles.appendingPathComponent(directoryName, isDirectory: true)
            try replaceKeysetFiles(from: source, to: destination)
            let backupDate = try createRecoveryCopy(from: destination, keysetID: id, reason: "import")
            registry.profiles.append(
                .init(
                    id: id,
                    name: manifest.displayName,
                    sourceLabel: inspection.requiresMigration ? "Imported legacy keyset" : "Imported .25 keyset",
                    directoryName: directoryName,
                    createdAt: nil,
                    importedAt: Date(),
                    lastActivatedAt: nil,
                    lastVerifiedBackupAt: backupDate
                ))
            try saveWalletRegistry(registry)
            return inspection.requiresMigration
                ? "Legacy identity imported and backed up. Activation will let the official .25 node preserve the Ed448 seniority root and generate the required post-quantum keys."
                : "Identity imported and backed up. It is ready to activate."

        case .create:
            var registry = try loadWalletRegistry()
            let id = manifest.keysetID ?? UUID()
            guard
                !registry.profiles.contains(where: {
                    $0.id == id || $0.name.caseInsensitiveCompare(manifest.displayName) == .orderedSame
                })
            else {
                throw HelperFailure.service("an identity package with this name or identifier already exists")
            }
            let generated = walletRoot.appendingPathComponent(
                "generation-\(id.uuidString.lowercased())", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: generated) }
            try generateFreshConfig(named: id.uuidString.lowercased(), in: generated)
            let source =
                generated
                .appendingPathComponent(".quilibrium/configs", isDirectory: true)
                .appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
            let directoryName = id.uuidString.lowercased()
            let destination = walletProfiles.appendingPathComponent(directoryName, isDirectory: true)
            try copyFreshPlaceholder(from: source, to: destination)
            registry.profiles.append(
                .init(
                    id: id,
                    name: manifest.displayName,
                    sourceLabel: "Created locally with the managed official qclient",
                    directoryName: directoryName,
                    createdAt: Date(),
                    importedAt: nil,
                    lastActivatedAt: nil,
                    lastVerifiedBackupAt: nil
                ))
            try saveWalletRegistry(registry)
            try activateWallet(id: id)
            return
                "New identity created, activated, validated, and protected by a recovery copy. Export that copy to separate encrypted storage next."

        case .activate:
            guard let id = manifest.keysetID else {
                throw HelperFailure.invalidManifest("the identity package to activate is missing")
            }
            try activateWallet(id: id)
            return "Identity switched atomically. The node restarted and passed local identity and metrics checks."

        case .exportRecovery:
            guard let id = manifest.keysetID else {
                throw HelperFailure.invalidManifest("the identity package to export is missing")
            }
            guard let parent = manifest.exportParentDirectory else {
                throw HelperFailure.invalidManifest("the selected recovery destination is missing")
            }
            _ = try prepareExternalRecoveryExport(
                id: id,
                parentPath: parent,
                configuration: configuration
            )
            var registry = try loadWalletRegistry()
            guard let index = registry.profiles.firstIndex(where: { $0.id == id }) else {
                throw HelperFailure.service("the exported identity package is not registered")
            }
            registry.profiles[index].lastExternalBackupAt = Date()
            try saveWalletRegistry(registry)
            return "Recovery copy saved and hash-verified in the selected encrypted destination."
        }
    }
}
