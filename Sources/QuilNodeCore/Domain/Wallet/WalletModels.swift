import Foundation

/// A node operator does not have one interchangeable "private key". Quilibrium
/// restores identity from a keyset: config.yml contains the legacy Ed448 peer
/// secret and the AES key that opens keys.yml; keys.yml contains the proving,
/// consensus, view, spend, device, and routing keys. Keeping that distinction in
/// the model prevents a UI from offering a dangerously incomplete backup.
public enum NodeKeysetFormat: String, Codable, Sendable, CaseIterable {
    case legacyPre25
    case transitional25
    case current25
    case empty
    case unreadable

    public var label: String {
        switch self {
        case .legacyPre25: "Legacy (pre-.25)"
        case .transitional25: ".25 migration required"
        case .current25: "Current .25"
        case .empty: "Empty keyset"
        case .unreadable: "Unrecognized keyset"
        }
    }
}

public enum KeysetHealth: String, Codable, Sendable {
    case ready, migrationRequired, incomplete, invalid
}

public struct KeysetPublicIdentity: Codable, Hashable, Sendable {
    public var currentPeerID: String?
    public var legacySeniorityPeerID: String?
    public var proverAddress: String?
    public var accountAddress: String?

    public init(
        currentPeerID: String? = nil,
        legacySeniorityPeerID: String? = nil,
        proverAddress: String? = nil,
        accountAddress: String? = nil
    ) {
        self.currentPeerID = currentPeerID
        self.legacySeniorityPeerID = legacySeniorityPeerID
        self.proverAddress = proverAddress
        self.accountAddress = accountAddress
    }
}

public struct ManagedKeyset: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var format: NodeKeysetFormat
    public var health: KeysetHealth
    public var isActive: Bool
    public var isManaged: Bool
    public var requiresMigration: Bool
    public var keyCount: Int
    public var keyTypes: [String]
    public var identities: KeysetPublicIdentity
    public var sourceLabel: String
    public var createdAt: Date?
    public var importedAt: Date?
    public var lastActivatedAt: Date?
    public var lastVerifiedBackupAt: Date?
    /// The latest verified copy written outside QuilNode's root-owned recovery
    /// vault. Kept separate so the UI never mistakes a local rollback snapshot
    /// for an operator-controlled off-device backup.
    public var lastExternalBackupAt: Date?
    public var automaticRecoveryCopies: Int
    public var fingerprint: String
    public var warnings: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        format: NodeKeysetFormat,
        health: KeysetHealth,
        isActive: Bool = false,
        isManaged: Bool = false,
        requiresMigration: Bool = false,
        keyCount: Int = 0,
        keyTypes: [String] = [],
        identities: KeysetPublicIdentity = .init(),
        sourceLabel: String,
        createdAt: Date? = nil,
        importedAt: Date? = nil,
        lastActivatedAt: Date? = nil,
        lastVerifiedBackupAt: Date? = nil,
        lastExternalBackupAt: Date? = nil,
        automaticRecoveryCopies: Int = 0,
        fingerprint: String,
        warnings: [String] = []
    ) {
        self.id = id
        self.name = name
        self.format = format
        self.health = health
        self.isActive = isActive
        self.isManaged = isManaged
        self.requiresMigration = requiresMigration
        self.keyCount = keyCount
        self.keyTypes = keyTypes
        self.identities = identities
        self.sourceLabel = sourceLabel
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.lastActivatedAt = lastActivatedAt
        self.lastVerifiedBackupAt = lastVerifiedBackupAt
        self.lastExternalBackupAt = lastExternalBackupAt
        self.automaticRecoveryCopies = automaticRecoveryCopies
        self.fingerprint = fingerprint
        self.warnings = warnings
    }
}

public struct WalletInventory: Codable, Sendable {
    public var schemaVersion: Int
    public var keysets: [ManagedKeyset]
    public var activeKeysetID: UUID?
    public var serviceSupportsTransactions: Bool
    public var recoveryVaultHealthy: Bool
    public var message: String?

    public init(
        schemaVersion: Int = 1,
        keysets: [ManagedKeyset] = [],
        activeKeysetID: UUID? = nil,
        serviceSupportsTransactions: Bool = false,
        recoveryVaultHealthy: Bool = false,
        message: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.keysets = keysets
        self.activeKeysetID = activeKeysetID
        self.serviceSupportsTransactions = serviceSupportsTransactions
        self.recoveryVaultHealthy = recoveryVaultHealthy
        self.message = message
    }

    public var activeKeyset: ManagedKeyset? {
        if let activeKeysetID {
            return keysets.first { $0.id == activeKeysetID }
        }
        return keysets.first(where: \.isActive)
    }
}

public struct KeysetInspection: Codable, Sendable {
    public var format: NodeKeysetFormat
    public var health: KeysetHealth
    public var requiresMigration: Bool
    public var keyCount: Int
    public var keyTypes: [String]
    public var fingerprint: String
    public var warnings: [String]
    public var hasConfig: Bool
    public var hasKeys: Bool

    public init(
        format: NodeKeysetFormat,
        health: KeysetHealth,
        requiresMigration: Bool,
        keyCount: Int,
        keyTypes: [String],
        fingerprint: String,
        warnings: [String],
        hasConfig: Bool,
        hasKeys: Bool
    ) {
        self.format = format
        self.health = health
        self.requiresMigration = requiresMigration
        self.keyCount = keyCount
        self.keyTypes = keyTypes
        self.fingerprint = fingerprint
        self.warnings = warnings
        self.hasConfig = hasConfig
        self.hasKeys = hasKeys
    }
}

public enum WalletTransactionKind: String, Codable, Sendable {
    case adoptActive, create, importKeyset, activate, exportRecovery
}

/// User-owned manifest passed across the privilege boundary. The daemon treats
/// every field as hostile, accepts only fixed operation kinds, validates file
/// ownership/no-symlink constraints, and never accepts private key bytes over IPC.
public struct WalletTransactionManifest: Codable, Sendable {
    public var schemaVersion = 2
    public var id: UUID
    public var kind: WalletTransactionKind
    public var keysetID: UUID?
    public var displayName: String
    /// Operator-selected source directory. The GUI passes this path as a
    /// capability but never opens either key file. The privileged service
    /// validates ownership, type, size, links, and exact filenames.
    public var selectedDirectory: String?
    /// Operator-selected parent for a recovery export. The privileged service
    /// creates a new child directory and verifies the copy before returning.
    public var exportParentDirectory: String?
    public var createdAt: Date
    public var confirmedBackupResponsibility: Bool

    public init(
        id: UUID = UUID(),
        kind: WalletTransactionKind,
        keysetID: UUID? = nil,
        displayName: String,
        selectedDirectory: String? = nil,
        exportParentDirectory: String? = nil,
        createdAt: Date = Date(),
        confirmedBackupResponsibility: Bool
    ) {
        self.id = id
        self.kind = kind
        self.keysetID = keysetID
        self.displayName = displayName
        self.selectedDirectory = selectedDirectory
        self.exportParentDirectory = exportParentDirectory
        self.createdAt = createdAt
        self.confirmedBackupResponsibility = confirmedBackupResponsibility
    }
}
