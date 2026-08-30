import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum IdentityTransactionContext: Identifiable {
    case adopt(ManagedKeyset)
    case create(suggestedName: String)
    case importKeyset(PendingKeysetImport)
    case activate(ManagedKeyset)

    var id: String {
        switch self {
        case .adopt(let keyset): "adopt-\(keyset.id.uuidString)"
        case .create: "create"
        case .importKeyset(let pending): "import-\(pending.id.uuidString)"
        case .activate(let keyset): "activate-\(keyset.id.uuidString)"
        }
    }

    var initialName: String {
        switch self {
        case .adopt(let keyset), .activate(let keyset): keyset.name
        case .create(let suggestedName): suggestedName
        case .importKeyset(let pending): pending.suggestedName
        }
    }
}

enum IdentityImportDisposition: String, CaseIterable, Identifiable {
    case activate
    case recoveryOnly

    var id: String { rawValue }
}

struct IdentityTransactionStage: Identifiable, Equatable {
    let number: Int
    let title: String
    let detail: String
    let symbol: String

    var id: Int { number }
}

struct IdentityTransactionFact: Identifiable, Equatable {
    enum State: Equatable {
        case verified
        case attention
        case neutral
    }

    let id: String
    let title: String
    let value: String
    let state: State
    let privacyField: PrivacyField?
    let mask: PrivacyMaskStyle?

    init(
        id: String,
        title: String,
        value: String,
        state: State = .verified,
        privacyField: PrivacyField? = nil,
        mask: PrivacyMaskStyle? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.state = state
        self.privacyField = privacyField
        self.mask = mask
    }
}

struct IdentityTransactionContractItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

struct IdentityTransactionMoment: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

struct IdentityTransactionPresentation {
    enum Kind: Equatable {
        case adopt
        case create
        case importKeyset
        case activate
    }

    let kind: Kind
    let eyebrow: String
    let title: String
    let detail: String
    let stages: [IdentityTransactionStage]
    let facts: [IdentityTransactionFact]
    let changes: [IdentityTransactionContractItem]
    let untouched: [IdentityTransactionContractItem]
    let moments: [IdentityTransactionMoment]
    let primaryTitle: String
    let primarySymbol: String
    let supportsDisposition: Bool
    let requiresEditableName: Bool
    let warningCount: Int

    func stages(for disposition: IdentityImportDisposition) -> [IdentityTransactionStage] {
        guard kind == .importKeyset, disposition == .recoveryOnly else { return stages }
        return stages.map { stage in
            guard stage.number == 4 else { return stage }
            return IdentityTransactionStage(
                number: stage.number,
                title: "Store",
                detail: "Planned",
                symbol: "archivebox.fill"
            )
        }
    }

    static func make(for context: IdentityTransactionContext) -> Self {
        switch context {
        case .adopt(let keyset): adopt(keyset)
        case .create: create()
        case .importKeyset(let pending): importKeyset(pending.inspection)
        case .activate(let keyset): activate(keyset)
        }
    }
}

extension IdentityTransactionPresentation {
    private static let preservedRuntime = [
        IdentityTransactionContractItem(
            id: "stores",
            title: "Node stores",
            detail: "Frames and local node data remain untouched.",
            symbol: "internaldrive.fill"
        ),
        IdentityTransactionContractItem(
            id: "config",
            title: "Node configuration",
            detail: "Runtime settings and listener ports are preserved.",
            symbol: "gearshape.fill"
        ),
        IdentityTransactionContractItem(
            id: "binary",
            title: "Node binary",
            detail: "The installed node version is not replaced.",
            symbol: "chevron.left.forwardslash.chevron.right"
        ),
    ]

    private static let protectedMoments = [
        IdentityTransactionMoment(
            id: "before",
            title: "Before",
            detail: "Validate the complete package and create rollback evidence.",
            symbol: "checkmark.shield.fill"
        ),
        IdentityTransactionMoment(
            id: "during",
            title: "During",
            detail: "Change only the complete identity pair; migrate through the official node if required.",
            symbol: "arrow.triangle.2.circlepath"
        ),
        IdentityTransactionMoment(
            id: "after",
            title: "After",
            detail: "Validate node health and restore the previous pair automatically on failure.",
            symbol: "checkmark.arrow.trianglehead.counterclockwise"
        ),
    ]

    private static func importKeyset(_ inspection: KeysetInspection) -> Self {
        let migrationState: IdentityTransactionFact.State = inspection.requiresMigration ? .attention : .verified
        return Self(
            kind: .importKeyset,
            eyebrow: "Protected import",
            title: "Complete keyset recognized",
            detail: "Review the local inspection and the exact activation boundary before anything changes.",
            stages: stages("Inspect", "Preserve", "Prepare", "Activate"),
            facts: [
                .init(id: "format", title: "Format", value: inspection.format.label),
                .init(
                    id: "entries",
                    title: "Key entries",
                    value: "\(inspection.keyCount) detected",
                    privacyField: .recoveryMetadata
                ),
                .init(
                    id: "fingerprint",
                    title: "Fingerprint",
                    value: inspection.fingerprint,
                    privacyField: .recoveryMetadata,
                    mask: .identifier
                ),
                .init(
                    id: "seniority",
                    title: "Seniority continuity",
                    value: "Ed448 root validated"
                ),
                .init(id: "validation", title: "Local validation", value: "Package passed"),
                .init(
                    id: "migration",
                    title: "Migration",
                    value: inspection.requiresMigration ? "Required on activation" : "Not required",
                    state: migrationState
                ),
            ],
            changes: [
                .init(
                    id: "managed-package",
                    title: "Managed identity copy",
                    detail: "The complete pair is added to the root-owned local recovery vault.",
                    symbol: "shippingbox.fill"
                ),
                .init(
                    id: "recovery-copy",
                    title: "Recovery copy",
                    detail: "A hash-verified rollback copy is created before activation.",
                    symbol: "clock.arrow.circlepath"
                ),
            ],
            untouched: preservedRuntime,
            moments: protectedMoments,
            primaryTitle: "Prepare protected import",
            primarySymbol: "arrow.right.circle.fill",
            supportsDisposition: true,
            requiresEditableName: true,
            warningCount: inspection.warnings.count
        )
    }

    private static func create() -> Self {
        Self(
            kind: .create,
            eyebrow: "New identity",
            title: "Create a protected node identity",
            detail:
                "The verified local client generates a complete identity, then the official node activates and validates it.",
            stages: stages("Plan", "Generate", "Protect", "Activate"),
            facts: [
                .init(id: "generator", title: "Generator", value: "Verified local qclient"),
                .init(id: "format", title: "Target format", value: NodeKeysetFormat.current25.label),
                .init(id: "custody", title: "Custody", value: "This Mac only"),
                .init(id: "validation", title: "Validation", value: "Official node health gate"),
            ],
            changes: [
                .init(
                    id: "new-package",
                    title: "New identity package",
                    detail: "A fresh complete keyset is generated by the verified local client.",
                    symbol: "person.badge.key.fill"
                ),
                .init(
                    id: "active-pair",
                    title: "Active identity pair",
                    detail: "The node switches only after rollback protection is ready.",
                    symbol: "arrow.triangle.2.circlepath"
                ),
            ],
            untouched: preservedRuntime,
            moments: [
                .init(
                    id: "before",
                    title: "Before",
                    detail: "Verify the local client and prepare an isolated generation workspace.",
                    symbol: "checkmark.shield.fill"
                ),
                .init(
                    id: "during",
                    title: "During",
                    detail: "Generate the complete package, protect it, and switch only the identity pair.",
                    symbol: "person.badge.key.fill"
                ),
                .init(
                    id: "after",
                    title: "After",
                    detail: "Validate node health and keep a hash-verified recovery copy.",
                    symbol: "checkmark.arrow.trianglehead.counterclockwise"
                ),
            ],
            primaryTitle: "Create & protect identity",
            primarySymbol: "plus.circle.fill",
            supportsDisposition: false,
            requiresEditableName: true,
            warningCount: 0
        )
    }

    private static func activate(_ keyset: ManagedKeyset) -> Self {
        Self(
            kind: .activate,
            eyebrow: "Protected switch",
            title: "Switch to this identity?",
            detail:
                "The node pauses only for the verified identity change and is restored automatically if health validation fails.",
            stages: stages("Inspect", "Snapshot", "Switch", "Verify"),
            facts: keysetFacts(keyset),
            changes: [
                .init(
                    id: "active-pair",
                    title: "Active identity pair",
                    detail: "config.yml and keys.yml switch as one recovery unit.",
                    symbol: "arrow.triangle.2.circlepath"
                ),
                .init(
                    id: "recovery-copy",
                    title: "Rollback evidence",
                    detail: "A verified copy of the current pair is created first.",
                    symbol: "clock.arrow.circlepath"
                ),
            ],
            untouched: preservedRuntime,
            moments: protectedMoments,
            primaryTitle: "Switch & verify",
            primarySymbol: "checkmark.shield.fill",
            supportsDisposition: false,
            requiresEditableName: false,
            warningCount: keyset.warnings.count
        )
    }

    private static func adopt(_ keyset: ManagedKeyset) -> Self {
        Self(
            kind: .adopt,
            eyebrow: "Recovery protection",
            title: "Protect the active identity",
            detail:
                "Register the already-running pair with the local recovery service without switching or restarting the node.",
            stages: stages("Inspect", "Register", "Snapshot", "Verify"),
            facts: keysetFacts(keyset),
            changes: [
                .init(
                    id: "registry",
                    title: "Recovery registry",
                    detail: "Public package metadata is registered locally.",
                    symbol: "list.bullet.rectangle.fill"
                ),
                .init(
                    id: "recovery-copy",
                    title: "Recovery copy",
                    detail: "A hash-verified copy is created before management begins.",
                    symbol: "clock.arrow.circlepath"
                ),
            ],
            untouched: preservedRuntime,
            moments: [
                .init(
                    id: "before", title: "Before", detail: "Validate the active complete pair.",
                    symbol: "checkmark.shield.fill"),
                .init(
                    id: "during", title: "During", detail: "Register metadata and create a verified recovery copy.",
                    symbol: "shippingbox.fill"),
                .init(
                    id: "after", title: "After", detail: "Keep the same running identity and node process.",
                    symbol: "checkmark.circle.fill"),
            ],
            primaryTitle: "Protect identity",
            primarySymbol: "checkmark.shield.fill",
            supportsDisposition: false,
            requiresEditableName: false,
            warningCount: keyset.warnings.count
        )
    }

    private static func stages(_ titles: String...) -> [IdentityTransactionStage] {
        let symbols = [
            "doc.text.magnifyingglass", "clock.badge.checkmark", "shippingbox.fill", "checkmark.shield.fill",
        ]
        return zip(titles.indices, titles).map { index, title in
            IdentityTransactionStage(
                number: index + 1,
                title: title,
                detail: index == 0 ? "Ready" : "Planned",
                symbol: symbols[index]
            )
        }
    }

    private static func keysetFacts(_ keyset: ManagedKeyset) -> [IdentityTransactionFact] {
        [
            .init(id: "format", title: "Format", value: keyset.format.label),
            .init(
                id: "entries",
                title: "Key entries",
                value: "\(keyset.keyCount) detected",
                privacyField: .recoveryMetadata
            ),
            .init(
                id: "fingerprint",
                title: "Fingerprint",
                value: keyset.fingerprint,
                privacyField: .recoveryMetadata,
                mask: .identifier
            ),
            .init(id: "custody", title: "Custody", value: keyset.isManaged ? "Managed locally" : "Protection required"),
            .init(
                id: "migration",
                title: "Migration",
                value: keyset.requiresMigration ? "Required on activation" : "Not required",
                state: keyset.requiresMigration ? .attention : .verified
            ),
        ]
    }
}
