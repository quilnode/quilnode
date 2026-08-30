import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let builtIns: [QuilTheme] = {
        let themes = [
            quilNode, quilNodeLight, classic, classicLight, graphite, graphiteLight, tokyoNight, tokyoNightLight,
            catppuccin, catppuccinLight, gruvbox, gruvboxLight, nord, nordLight,
            rosePine, rosePineDark, everforest, everforestLight, kanagawa, kanagawaLight,
            matteBlack, matteBlackLight,
            shl0ms, shl0msDark, nousResearch, nousResearchDark,
        ]
        let modesByFamily = Dictionary(grouping: themes, by: \.familyID).mapValues { Set($0.map(\.appearance)) }
        assert(
            modesByFamily.values.allSatisfy { $0 == Set([.light, .dark]) },
            "Every built-in theme family must provide light and dark modes.")
        return themes
    }()

    static func makeBuiltInVariant(
        base: QuilTheme,
        id: String,
        appearance: QuilThemeAppearance,
        summary: String,
        palette: QuilThemePaletteDocument
    ) -> QuilTheme {
        let pack = QuilThemePack(
            metadata: .init(
                id: id, name: base.name, author: base.author, version: base.version,
                appearance: appearance, summary: summary, tags: ["omarchy", appearance.rawValue]
            ),
            colors: palette,
            style: .init()
        )
        let resolved = base.applying(pack)
        return .init(
            id: resolved.id, familyID: base.familyID, name: resolved.name, author: resolved.author,
            version: resolved.version,
            appearance: resolved.appearance, summary: resolved.summary, tags: resolved.tags,
            colors: resolved.colors, metrics: resolved.metrics, typography: resolved.typography,
            components: resolved.components, recipes: resolved.recipes, isBuiltIn: true
        )
    }

    static func makeBuiltIn(
        id: String,
        name: String,
        appearance: QuilThemeAppearance = .dark,
        summary: String,
        familyID: String? = nil,
        author: String = "QuilNode · Omarchy palette",
        tags: [String]? = nil,
        palette: QuilThemePaletteDocument,
        style: QuilThemeStyleDocument = .init()
    ) -> QuilTheme {
        let pack = QuilThemePack(
            metadata: .init(
                id: id, name: name, author: author, version: "1.0.0", appearance: appearance, summary: summary,
                tags: tags ?? ["omarchy", appearance.rawValue]),
            colors: palette,
            style: style
        )
        let resolved = classic.applying(pack)
        return .init(
            id: resolved.id, familyID: familyID ?? resolved.familyID, name: resolved.name, author: resolved.author,
            version: resolved.version,
            appearance: resolved.appearance, summary: resolved.summary, tags: resolved.tags,
            colors: resolved.colors, metrics: resolved.metrics, typography: resolved.typography,
            components: resolved.components, recipes: resolved.recipes, isBuiltIn: true
        )
    }
}
