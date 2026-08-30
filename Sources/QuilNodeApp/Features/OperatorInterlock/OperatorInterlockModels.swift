import Foundation

enum OperatorInterlockTone: String, Sendable {
    case accent
    case success
    case information
    case warning
    case destructive
}

struct OperatorInterlockStep: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tone: OperatorInterlockTone
}

struct OperatorInterlockScopeItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

struct OperatorInterlockDecision: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let actionTitle: String
    let symbol: String
    let tone: OperatorInterlockTone
    let bullets: [String]
}

struct OperatorInterlockModel: Equatable, Identifiable, Sendable {
    let id: String
    let eyebrow: String
    let title: String
    let outcome: String
    let symbol: String
    let tone: OperatorInterlockTone
    let steps: [OperatorInterlockStep]
    let changes: [OperatorInterlockScopeItem]
    let preserved: [OperatorInterlockScopeItem]
    let verification: [String]
    let trustNote: String
    let decisions: [OperatorInterlockDecision]
    let defaultDecisionID: String
    let cancelTitle: String

    var defaultDecision: OperatorInterlockDecision {
        decisions.first(where: { $0.id == defaultDecisionID }) ?? decisions[0]
    }
}
