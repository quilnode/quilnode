import Foundation

public struct QuilBalanceComponent: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable {
        case observed
        case noRoot
        case notApplicable
        case unavailable
    }

    public var state: State
    /// Decimal QUIL, never binary floating point. Rewards are not spendable coins.
    public var amount: String?
    public var coinCount: UInt64?
    public var frame: UInt64?

    public init(state: State, amount: String? = nil, coinCount: UInt64? = nil, frame: UInt64? = nil) {
        self.state = state
        self.amount = amount
        self.coinCount = coinCount
        self.frame = frame
    }
}

public struct QuilBalance: Codable, Equatable, Sendable {
    /// The legacy total, or confidential coins only for the modern client.
    /// Never adds claimable rewards or unshielded coins to this amount.
    public var amount: String?
    public var account: String?
    public var confidential: QuilBalanceComponent?
    public var legacy: QuilBalanceComponent?
    public var rewards: QuilBalanceComponent?

    public init(
        amount: String? = nil, account: String? = nil,
        confidential: QuilBalanceComponent? = nil,
        legacy: QuilBalanceComponent? = nil,
        rewards: QuilBalanceComponent? = nil
    ) {
        self.amount = amount
        self.account = account
        self.confidential = confidential
        self.legacy = legacy
        self.rewards = rewards
    }

    public var isLegacyFormat: Bool { confidential == nil && legacy == nil && rewards == nil }

    public var isComplete: Bool {
        if isLegacyFormat { return amount != nil }
        return [confidential, legacy, rewards].allSatisfy { $0 != nil && $0?.state != .unavailable }
    }
}
