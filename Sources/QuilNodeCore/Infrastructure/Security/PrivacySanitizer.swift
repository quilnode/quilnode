import Foundation

/// Removes only machine-, identity-, or service-specific substrings from
/// free-form presentation text. Structured values should use the app's typed
/// privacy fields so labels, units, controls, and layout remain useful.
public enum PrivacySanitizer {
    public static func display(_ text: String, enabled: Bool) -> String {
        guard enabled else { return text }

        return replacements.reduce(text) { partial, replacement in
            replacement.expression.stringByReplacingMatches(
                in: partial,
                range: NSRange(partial.startIndex..., in: partial),
                withTemplate: replacement.template
            )
        }
    }

    private static let replacements: [(expression: NSRegularExpression, template: String)] = [
        replacement(#"(/Users/)[^/\s]+"#, with: "$1•••"),
        replacement(#"\b(?:\d{1,3}\.){3}\d{1,3}:\d{1,5}\b"#, with: "•••.•••.•••.•••:•••••"),
        replacement(#"\b(?:\d{1,3}\.){3}\d{1,3}\b"#, with: "•••.•••.•••.•••"),
        replacement(#"(/(?:tcp|udp)/)\d{1,5}\b"#, with: "$1•••••"),
        replacement(#"(?i)(\bports?(?:\s*(?:=|:)|\s+))\d{1,5}\b"#, with: "$1•••••"),
        replacement(#"\bQm[1-9A-HJ-NP-Za-km-z]{44}\b"#, with: "Qm••••••••••••••••"),
        replacement(#"\b12D3KooW[1-9A-HJ-NP-Za-km-z]+\b"#, with: "12D3KooW••••••••"),
        replacement(#"\b0x[0-9a-fA-F]{32,}\b"#, with: "0x••••••••••••••••"),
        replacement(#"\b[0-9a-fA-F]{64,}\b"#, with: "••••••••••••••••"),
    ]

    private static func replacement(
        _ pattern: String,
        with template: String
    ) -> (NSRegularExpression, String) {
        // Patterns are compile-time constants and covered by self-tests.
        (try! NSRegularExpression(pattern: pattern), template)
    }
}
