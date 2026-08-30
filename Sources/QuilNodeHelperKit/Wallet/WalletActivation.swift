import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func activateWallet(id: UUID) throws {
        var registry = try loadWalletRegistry()
        guard let index = registry.profiles.firstIndex(where: { $0.id == id }) else {
            throw HelperFailure.service("the selected identity package no longer exists")
        }
        let source = walletProfiles.appendingPathComponent(registry.profiles[index].directoryName, isDirectory: true)
        let inspection = try inspectKeyset(source)
        let generatedPlaceholder = registry.profiles[index].createdAt != nil && inspection.health == "incomplete"
        guard inspection.health != "invalid", inspection.health != "incomplete" || generatedPlaceholder else {
            throw HelperFailure.service("the selected identity package is incomplete")
        }

        let active = nodeDirectory.appendingPathComponent(".config", isDirectory: true)
        let priorID: UUID
        if let registered = registry.activeKeysetID {
            priorID = registered
        } else {
            priorID = stableUUID(from: try inspectKeyset(active).fingerprint)
        }
        _ = try createRecoveryCopy(from: active, keysetID: priorID, reason: "before-switch")
        let oldConfig = try readSecureRegularFile(
            active.appendingPathComponent("config.yml"),
            maximumBytes: 2_000_000
        )
        let oldKeys = try readSecureRegularFile(
            active.appendingPathComponent("keys.yml"),
            maximumBytes: 20_000_000
        )

        do {
            if isLoaded() { try performLifecycle(.stop) }
            try installIdentityOnly(
                from: source,
                runtimeConfig: oldConfig,
                to: active,
                allowsFreshPlaceholder: generatedPlaceholder
            )
            try restartAndValidate(expectedVersion: nil)
            // The official .25 node owns cryptographic migration. Persist the
            // exact post-start pair, including preserved `-legacy-*` entries.
            try replaceKeysetFiles(from: active, to: source)
            let backupDate = try createRecoveryCopy(from: active, keysetID: id, reason: "after-activation")
            registry.activeKeysetID = id
            registry.profiles[index].lastActivatedAt = Date()
            registry.profiles[index].lastVerifiedBackupAt = backupDate
            try saveWalletRegistry(registry)
        } catch {
            try? atomicWriteKeysetFile(oldConfig, to: active.appendingPathComponent("config.yml"))
            try? atomicWriteKeysetFile(oldKeys, to: active.appendingPathComponent("keys.yml"))
            try? restartAndValidate(expectedVersion: nil)
            throw HelperFailure.healthCheck(
                "Identity activation failed; the previous keyset was restored and restarted: \(error)")
        }
    }
}
