import Foundation

struct ThemeLibraryPresentation {
    static func filteredThemes(_ themes: [QuilTheme], query: String) -> [QuilTheme] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return themes }

        return themes.filter { theme in
            searchableText(for: theme).localizedStandardContains(term)
        }
    }

    static func variantLabel(supportsLight: Bool, supportsDark: Bool) -> String {
        switch (supportsLight, supportsDark) {
        case (true, true): "L · D"
        case (true, false): "LIGHT"
        case (false, true): "DARK"
        case (false, false): "SYSTEM"
        }
    }

    static func provenance(for theme: QuilTheme) -> String {
        theme.isBuiltIn ? "Built in · v\(theme.version)" : "Custom · \(theme.author)"
    }

    static func summary(for theme: QuilTheme) -> String {
        theme.summary ?? (theme.isBuiltIn ? "Bundled theme family" : "Custom theme by \(theme.author)")
    }

    private static func searchableText(for theme: QuilTheme) -> String {
        ([theme.name, theme.author, theme.summary ?? ""] + theme.tags)
            .joined(separator: " ")
    }
}
