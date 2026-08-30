import Foundation

/// Optional light/dark mode overrides for a schema-4 theme family. The base
/// palette and style remain the fallback for omitted tokens in either mode.
public struct QuilThemeVariantsDocument: Codable, Hashable, Sendable {
    public struct Variant: Codable, Hashable, Sendable {
        public var colors: QuilThemePaletteDocument
        public var style: QuilThemeStyleDocument

        public init(colors: QuilThemePaletteDocument = .init(), style: QuilThemeStyleDocument = .init()) {
            self.colors = colors
            self.style = style
        }

        public func validationIssues(prefix: String) -> [String] {
            colors.validationIssues().map { "\(prefix).\($0)" }
                + style.validationIssues().map { "\(prefix).\($0)" }
        }
    }

    public var light: Variant?
    public var dark: Variant?

    public init(light: Variant? = nil, dark: Variant? = nil) {
        self.light = light
        self.dark = dark
    }

    public func validationIssues() -> [String] {
        (light?.validationIssues(prefix: "variants.light") ?? [])
            + (dark?.validationIssues(prefix: "variants.dark") ?? [])
    }
}
