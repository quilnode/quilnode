import Foundation

public enum QuilBalanceParser {
    public static func parse(_ output: String) -> QuilBalance? {
        let pattern = #"Total balance:\s*([^\s]+)\s+QUIL\s+\(Account\s+(0x[0-9a-fA-F]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: output,
                range: NSRange(output.startIndex..., in: output)
            ),
            let amountRange = Range(match.range(at: 1), in: output),
            let accountRange = Range(match.range(at: 2), in: output)
        else { return nil }

        return QuilBalance(
            amount: String(output[amountRange]),
            account: String(output[accountRange])
        )
    }
}
