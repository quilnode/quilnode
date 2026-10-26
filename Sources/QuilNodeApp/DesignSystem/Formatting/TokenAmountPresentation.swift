import Foundation

/// Decimal strings stay exact all the way to the copy action. Compact display
/// truncates only fractional digits and explicitly marks lost precision.
struct TokenAmountPresentation: Equatable {
    let exact: String?
    let compact: String
    let isApproximate: Bool

    init(_ value: String?, fractionDigits: Int = 6, locale: Locale = .current) {
        guard let value, !value.isEmpty, value.count <= 128,
            value.range(of: #"^[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil
        else {
            exact = nil
            compact = "—"
            isApproximate = false
            return
        }
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        let integer = String(parts[0].drop(while: { $0 == "0" }))
        let whole = integer.isEmpty ? "0" : integer
        var fraction = parts.count > 1 ? String(parts[1]) : ""
        while fraction.last == "0" { fraction.removeLast() }
        exact = whole + (fraction.isEmpty ? "" : "." + fraction)
        let limit = max(1, min(fractionDigits, 12))
        isApproximate = fraction.count > limit
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        let decimal = formatter.decimalSeparator ?? "."
        let groups = Self.group(whole, formatter: formatter)
        var visible = String(fraction.prefix(limit))
        if isApproximate, whole == "0", visible.allSatisfy({ $0 == "0" }) {
            compact = "<0" + decimal + String(repeating: "0", count: limit - 1) + "1"
        } else {
            while visible.last == "0" { visible.removeLast() }
            compact = (isApproximate ? "≈" : "") + groups + (visible.isEmpty ? "" : decimal + visible)
        }
    }

    private static func group(_ whole: String, formatter: NumberFormatter) -> String {
        let primary = max(formatter.groupingSize, 1)
        let secondary = formatter.secondaryGroupingSize > 0 ? formatter.secondaryGroupingSize : primary
        var remainder = whole[...]
        var groups: [String] = []
        var size = primary
        while remainder.count > size {
            groups.insert(String(remainder.suffix(size)), at: 0)
            remainder = remainder.dropLast(size)
            size = secondary
        }
        groups.insert(String(remainder), at: 0)
        return groups.joined(separator: formatter.groupingSeparator ?? ",")
    }
}
