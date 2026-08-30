import Foundation

/// Portable, code-free description of a QuilNode visual theme.
///
/// Theme files use the `.quiltheme.json` suffix. Every field below is optional
/// except the identity metadata so a custom theme can inherit from a built-in
/// theme and override only the tokens it needs.
public struct QuilThemeManifest: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var author: String
    public var version: String
    public var base: String?
    public var appearance: QuilThemeAppearance?
    public var colors: QuilThemeColorOverrides
    public var metrics: QuilThemeMetricOverrides
    public var typography: QuilThemeTypographyOverrides

    public init(
        schemaVersion: Int = QuilThemeManifest.currentSchemaVersion,
        id: String,
        name: String,
        author: String,
        version: String,
        base: String? = "quil.classic",
        appearance: QuilThemeAppearance? = nil,
        colors: QuilThemeColorOverrides = .init(),
        metrics: QuilThemeMetricOverrides = .init(),
        typography: QuilThemeTypographyOverrides = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.author = author
        self.version = version
        self.base = base
        self.appearance = appearance
        self.colors = colors
        self.metrics = metrics
        self.typography = typography
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []
        let identifierPattern = #"^[a-z0-9]+(?:[.-][a-z0-9]+)*$"#

        if schemaVersion != Self.currentSchemaVersion {
            issues.append("Unsupported schemaVersion \(schemaVersion); expected \(Self.currentSchemaVersion).")
        }
        if id.range(of: identifierPattern, options: .regularExpression) == nil {
            issues.append("id must use lowercase letters, numbers, dots, or hyphens.")
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("name cannot be empty.")
        }
        if author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("author cannot be empty.")
        }
        if version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("version cannot be empty.")
        }
        if id.count > 64 || (base?.count ?? 0) > 64 {
            issues.append("theme ids are limited to 64 characters.")
        }
        if name.count > 64 { issues.append("name is limited to 64 characters.") }
        if author.count > 80 { issues.append("author is limited to 80 characters.") }
        if version.count > 32 { issues.append("version is limited to 32 characters.") }

        for (token, value) in colors.values {
            if !Self.isValidColor(value) {
                issues.append("colors.\(token) must be #RRGGBB, #RRGGBBAA, or a supported system:* color.")
            }
        }

        if let value = metrics.sidebarCollapsedWidth, !(56...96).contains(value) {
            issues.append("metrics.sidebarCollapsedWidth must be between 56 and 96.")
        }
        if let value = metrics.sidebarExpandedWidth, !(160...320).contains(value) {
            issues.append("metrics.sidebarExpandedWidth must be between 160 and 320.")
        }
        if let value = metrics.navigationRowHeight, !(36...64).contains(value) {
            issues.append("metrics.navigationRowHeight must be between 36 and 64.")
        }
        if let value = metrics.controlCornerRadius, !(6...32).contains(value) {
            issues.append("metrics.controlCornerRadius must be between 6 and 32.")
        }
        if let value = metrics.heroCornerRadius, !(8...40).contains(value) {
            issues.append("metrics.heroCornerRadius must be between 8 and 40.")
        }
        if let value = metrics.spacingScale, !(0.8...1.35).contains(value) {
            issues.append("metrics.spacingScale must be between 0.8 and 1.35.")
        }
        if let value = typography.scale, !(0.85...1.25).contains(value) {
            issues.append("typography.scale must be between 0.85 and 1.25.")
        }
        return issues
    }

    private static func isValidColor(_ value: String) -> Bool {
        if value.hasPrefix("system:") {
            return [
                "system:accent", "system:primary", "system:secondary",
                "system:window", "system:control", "system:separator",
            ].contains(value)
        }
        guard value.first == "#" else { return false }
        let hex = value.dropFirst()
        guard hex.count == 6 || hex.count == 8 else { return false }
        return hex.allSatisfy(\.isHexDigit)
    }
}
