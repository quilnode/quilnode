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
