import Foundation

/// Metadata stored in `<name>.quiltheme/theme.json`.
public struct QuilThemePackMetadata: Codable, Hashable, Identifiable, Sendable {
    public static let currentSchemaVersion = 4
    public static let supportedSchemaVersions = 2...currentSchemaVersion

    public var schemaVersion: Int
    public var id: String
    public var name: String
    public var author: String
    public var version: String
    public var base: String
    public var appearance: QuilThemeAppearance
    public var summary: String?
    public var tags: [String]

    public init(
        schemaVersion: Int = QuilThemePackMetadata.currentSchemaVersion,
        id: String,
        name: String,
        author: String,
        version: String,
        base: String = "quil.classic",
        appearance: QuilThemeAppearance = .dark,
        summary: String? = nil,
        tags: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.author = author
        self.version = version
        self.base = base
        self.appearance = appearance
        self.summary = summary
        self.tags = tags
    }

    public func validationIssues() -> [String] {
        var issues: [String] = []
        let identifierPattern = #"^[a-z0-9]+(?:[.-][a-z0-9]+)*$"#
        if !Self.supportedSchemaVersions.contains(schemaVersion) {
            issues.append(
                "Unsupported schemaVersion \(schemaVersion); supported versions are \(Self.supportedSchemaVersions.lowerBound)–\(Self.supportedSchemaVersions.upperBound)."
            )
        }
        if id.range(of: identifierPattern, options: .regularExpression) == nil {
            issues.append("id must use lowercase letters, numbers, dots, or hyphens.")
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("name cannot be empty.") }
        if author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("author cannot be empty.") }
        if version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("version cannot be empty.") }
        if base.range(of: identifierPattern, options: .regularExpression) == nil {
            issues.append("base must be a valid theme id.")
        }
        if id.count > 64 || base.count > 64 { issues.append("theme ids are limited to 64 characters.") }
        if name.count > 64 { issues.append("name is limited to 64 characters.") }
        if author.count > 80 { issues.append("author is limited to 80 characters.") }
        if version.count > 32 { issues.append("version is limited to 32 characters.") }
        if summary?.count ?? 0 > 240 { issues.append("summary is limited to 240 characters.") }
        if tags.count > 8 || tags.contains(where: { $0.count > 32 }) {
            issues.append("themes may declare at most 8 tags of 32 characters each.")
        }
        return issues
    }
}
