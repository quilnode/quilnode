import Foundation

public enum QuilBalanceParser {
    public static func parse(_ output: String) -> QuilBalance? {
        guard output.utf8.count <= 1_000_000 else { return nil }
        var result = QuilBalance()
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let values = captures(
                #"^Total balance: ([0-9]+(?:\.[0-9]+)?) QUIL \(Account (0x[0-9a-fA-F]+)\)$"#, line
            ), values[0].count <= 80 {
                result.amount = values[0]
                result.account = values[1]
            } else if let values = captures(
                #"^Claimable prover rewards: ([0-9]+(?:\.[0-9]+)?) QUIL \(witness cites global frame ([0-9]+); requires minting\)$"#,
                line
            ), values[0].count <= 80, let frame = UInt64(values[1]) {
                result.rewards = .init(state: .observed, amount: values[0], frame: frame)
            } else if line.hasPrefix("Claimable prover rewards: unavailable (") {
                result.rewards = .init(state: .unavailable)
            } else if let values = captures(
                #"^(?:Confidential coins: )?([0-9]+) base units across ([0-9]+) coins reported unspent by the configured node \(not a finalized balance\)$"#,
                line
            ), let amount = quilFromBaseUnits(values[0]), let count = UInt64(values[1]) {
                result.confidential = .init(state: .observed, amount: amount, coinCount: count)
            } else if let values = captures(
                #"^Unshielded legacy coins: ([0-9]+) base units across ([0-9]+) coins \([0-9]+ already shielded\)$"#,
                line
            ), let amount = quilFromBaseUnits(values[0]), let count = UInt64(values[1]) {
                result.legacy = .init(state: .observed, amount: amount, coinCount: count)
            } else if line == "Unshielded legacy coins: none (this node has no Ed448 identity)" {
                result.legacy = .init(state: .notApplicable)
            } else if line.hasPrefix("Unshielded legacy coins: unavailable (") {
                result.legacy = .init(state: .unavailable)
            } else if line == "Confidential QUIL coins: none exist on the network yet (no QUIL root published)"
                || line == "Confidential coins: none exist in this application yet (no root published)"
            {
                result.confidential = .init(state: .noRoot, amount: "0", coinCount: 0)
            } else if line.hasPrefix("Confidential coins: unavailable (") {
                result.confidential = .init(state: .unavailable)
            }
        }
        if !result.isLegacyFormat {
            result.amount = result.confidential?.amount
            result.account = nil
            return result
        }
        return result.amount == nil ? nil : result
    }

    /// Exact division by upstream's 8,000,000,000 base units per QUIL,
    /// including a single base unit (0.000000000125 QUIL).
    static func quilFromBaseUnits(_ value: String) -> String? {
        guard !value.isEmpty, value.count <= 39,
            value.utf8.allSatisfy({ (48...57).contains($0) })
        else { return nil }
        let normalized = String(value.drop(while: { $0 == "0" }))
        let maximum = "340282366920938463463374607431768211455"
        guard normalized.count < maximum.count || normalized <= maximum else { return nil }
        var remainder: UInt64 = 0
        var quotient = ""
        for digit in value.utf8 {
            remainder = remainder * 10 + UInt64(digit - 48)
            quotient += String(remainder / 8_000_000_000)
            remainder %= 8_000_000_000
        }
        quotient = String(quotient.drop(while: { $0 == "0" }))
        if quotient.isEmpty { quotient = "0" }
        guard remainder != 0 else { return quotient }
        let fraction = String(remainder * 125)
        let padded = String(repeating: "0", count: 12 - fraction.count) + fraction
        return quotient + "." + String(padded.reversed().drop(while: { $0 == "0" }).reversed())
    }

    private static func captures(_ pattern: String, _ line: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else { return nil }
        return (1..<match.numberOfRanges).compactMap {
            Range(match.range(at: $0), in: line).map { String(line[$0]) }
        }
    }
}
