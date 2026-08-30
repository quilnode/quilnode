import Foundation

enum WalletTransactionKind: String, Codable {
    case adoptActive, create, importKeyset, activate, exportRecovery
}

struct WalletTransactionManifest: Codable {
    var schemaVersion: Int
    var id: UUID
    var kind: WalletTransactionKind
    var keysetID: UUID?
    var displayName: String
    var selectedDirectory: String?
    var exportParentDirectory: String?
    var createdAt: Date
    var confirmedBackupResponsibility: Bool
}

struct StoredWalletProfile: Codable {
    var id: UUID
    var name: String
    var sourceLabel: String
    var directoryName: String
    var createdAt: Date?
    var importedAt: Date?
    var lastActivatedAt: Date?
    var lastVerifiedBackupAt: Date?
    var lastExternalBackupAt: Date? = nil
}

struct WalletRegistry: Codable {
    var schemaVersion = 1
    var activeKeysetID: UUID?
    var profiles: [StoredWalletProfile]
}

struct KeysetInspectionPayload: Codable {
    var format: String
    var health: String
    var requiresMigration: Bool
    var keyCount: Int
    var keyTypes: [String]
    var fingerprint: String
    var warnings: [String]
    var hasConfig: Bool
    var hasKeys: Bool
}

struct WalletPublicIdentityPayload: Codable {
    var currentPeerID: String?
    var legacySeniorityPeerID: String?
    var proverAddress: String?
    var accountAddress: String?
}

struct ManagedKeysetPayload: Codable {
    var id: UUID
    var name: String
    var format: String
    var health: String
    var isActive: Bool
    var isManaged: Bool
    var requiresMigration: Bool
    var keyCount: Int
    var keyTypes: [String]
    var identities: WalletPublicIdentityPayload
    var sourceLabel: String
    var createdAt: Date?
    var importedAt: Date?
    var lastActivatedAt: Date?
    var lastVerifiedBackupAt: Date?
    var lastExternalBackupAt: Date?
    var automaticRecoveryCopies: Int
    var fingerprint: String
    var warnings: [String]
}

struct WalletInventoryPayload: Codable {
    var schemaVersion = 1
    var keysets: [ManagedKeysetPayload]
    var activeKeysetID: UUID?
    var serviceSupportsTransactions = true
    var recoveryVaultHealthy: Bool
    var message: String?
}
