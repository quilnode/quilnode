import Foundation

/// A single source of truth for action enablement and its visible explanation.
/// Every disabled update action must say why; button state must never be the
/// only place where an operator can discover a prerequisite.
struct UpdateActionAvailability: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case ready
        case blocked
        case current
    }

    var state: State
    var message: String

    var isEnabled: Bool { state == .ready }
    var systemImage: String {
        switch state {
        case .ready: "checkmark.circle.fill"
        case .blocked: "info.circle.fill"
        case .current: "checkmark.seal.fill"
        }
    }

    static func ready(_ message: String) -> Self {
        Self(state: .ready, message: message)
    }

    static func blocked(_ message: String) -> Self {
        Self(state: .blocked, message: message)
    }

    static func current(_ message: String) -> Self {
        Self(state: .current, message: message)
    }
}
