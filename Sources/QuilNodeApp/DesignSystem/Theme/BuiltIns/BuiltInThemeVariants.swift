import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // Every bundled family owns both appearances. These are canonical light
    // companions where the upstream palette provides one (Tokyo Day,
    // Catppuccin Latte, Gruvbox Light, Rosé Pine Dawn, Everforest Light and
    // Kanagawa Lotus), plus restrained family-native companions for Graphite,
    // Nord and Matte Black.
    static let graphiteLight = makeBuiltInVariant(
        base: graphite, id: "quil.graphite.light", appearance: .light,
        summary: "Graphite translated to cool paper, ink and cyan telemetry.",
        palette: .init(
            accent: "#087E8B", selection: "#D8E2E5", muted: "#B5C2C6",
            background: "#F4F6F7", darkBackground: "#E8ECEE", darkerBackground: "#D9E0E3", lighterBackground: "#FFFFFF",
            foreground: "#263238", darkForeground: "#6D7B81", lightForeground: "#435159", brightForeground: "#111719",
            red: "#C33B3B", yellow: "#8B6B00", orange: "#B85D1D", green: "#287A4E", cyan: "#087E8B", blue: "#5652C7",
            magenta: "#8D45B5"
        )
    )

    static let tokyoNightLight = makeBuiltInVariant(
        base: tokyoNight, id: "omarchy.tokyo-night.light", appearance: .light,
        summary: "Tokyo Night Day: cool daylight surfaces with crisp blue focus.",
        palette: .init(
            accent: "#2E7DE9", selection: "#C4C8DA", muted: "#B7BDD2",
            background: "#E1E2E7", darkBackground: "#D5D6DB", darkerBackground: "#C8CAD2", lighterBackground: "#F3F3F5",
            foreground: "#3760BF", darkForeground: "#8990B3", lightForeground: "#4C5A88", brightForeground: "#1A2B5A",
            red: "#F52A65", yellow: "#8C6C3E", orange: "#B15C00", green: "#587539", cyan: "#007197", blue: "#2E7DE9",
            magenta: "#9854F1"
        )
    )

    static let catppuccinLight = makeBuiltInVariant(
        base: catppuccin, id: "omarchy.catppuccin.light", appearance: .light,
        summary: "Catppuccin Latte's warm paper base and saturated pastel accents.",
        palette: .init(
            accent: "#1E66F5", selection: "#CCD0DA", muted: "#BCC0CC",
            background: "#EFF1F5", darkBackground: "#E6E9EF", darkerBackground: "#DCE0E8", lighterBackground: "#FFFFFF",
            foreground: "#4C4F69", darkForeground: "#8C8FA1", lightForeground: "#6C6F85", brightForeground: "#303446",
            red: "#D20F39", yellow: "#DF8E1D", orange: "#FE640B", green: "#40A02B", cyan: "#179299", blue: "#1E66F5",
            magenta: "#8839EF"
        )
    )

    static let gruvboxLight = makeBuiltInVariant(
        base: gruvbox, id: "omarchy.gruvbox.light", appearance: .light,
        summary: "Gruvbox Light's warm parchment and grounded retro signals.",
        palette: .init(
            accent: "#076678", selection: "#D5C4A1", muted: "#BDAE93",
            background: "#FBF1C7", darkBackground: "#EBDBB2", darkerBackground: "#D5C4A1", lighterBackground: "#F9F5D7",
            foreground: "#3C3836", darkForeground: "#928374", lightForeground: "#665C54", brightForeground: "#282828",
            red: "#9D0006", yellow: "#B57614", orange: "#AF3A03", green: "#79740E", cyan: "#427B58", blue: "#076678",
            magenta: "#8F3F71"
        )
    )

    static let nordLight = makeBuiltInVariant(
        base: nord, id: "omarchy.nord.light", appearance: .light,
        summary: "Nord Snow Storm: arctic paper with Frost and Aurora signals.",
        palette: .init(
            accent: "#5E81AC", selection: "#D8DEE9", muted: "#C8D0DB",
            background: "#ECEFF4", darkBackground: "#E5E9F0", darkerBackground: "#D8DEE9", lighterBackground: "#FFFFFF",
            foreground: "#2E3440", darkForeground: "#7B8494", lightForeground: "#4C566A", brightForeground: "#242933",
            red: "#BF616A", yellow: "#B58A37", orange: "#D08770", green: "#668A50", cyan: "#2E7E91", blue: "#5E81AC",
            magenta: "#9A6F93"
        )
    )

    static let rosePineDark = makeBuiltInVariant(
        base: rosePine, id: "omarchy.rose-pine.dark", appearance: .dark,
        summary: "Rosé Pine Moon's deep plum base and soft Soho accents.",
        palette: .init(
            accent: "#9CCFD8", selection: "#44415A", muted: "#393552",
            background: "#232136", darkBackground: "#1D1A2E", darkerBackground: "#171522", lighterBackground: "#2A273F",
            foreground: "#E0DEF4", darkForeground: "#6E6A86", lightForeground: "#908CAA", brightForeground: "#F5F2FF",
            red: "#EB6F92", yellow: "#F6C177", orange: "#EA9A97", green: "#3E8FB0", cyan: "#9CCFD8", blue: "#56949F",
            magenta: "#C4A7E7"
        )
    )

    static let everforestLight = makeBuiltInVariant(
        base: everforest, id: "omarchy.everforest.light", appearance: .light,
        summary: "Everforest Light's warm forest paper and soft green contrast.",
        palette: .init(
            accent: "#3A94C5", selection: "#E6E2CC", muted: "#D5D2BD",
            background: "#FDF6E3", darkBackground: "#F4F0D9", darkerBackground: "#E6E2CC", lighterBackground: "#FFFBF0",
            foreground: "#5C6A72", darkForeground: "#939F91", lightForeground: "#708089", brightForeground: "#3A444A",
            red: "#F85552", yellow: "#DFA000", orange: "#F57D26", green: "#8DA101", cyan: "#35A77C", blue: "#3A94C5",
            magenta: "#DF69BA"
        )
    )

    static let kanagawaLight = makeBuiltInVariant(
        base: kanagawa, id: "omarchy.kanagawa.light", appearance: .light,
        summary: "Kanagawa Lotus: sunlit paper, violet ink and botanical accents.",
        palette: .init(
            accent: "#4D699B", selection: "#C9CBD1", muted: "#D5CEA3",
            background: "#F2ECBC", darkBackground: "#E5DDB0", darkerBackground: "#DCD5AC", lighterBackground: "#FFF9D9",
            foreground: "#545464", darkForeground: "#8A8980", lightForeground: "#716E61", brightForeground: "#43436C",
            red: "#C84053", yellow: "#77713F", orange: "#CC6D00", green: "#6F894E", cyan: "#597B75", blue: "#4D699B",
            magenta: "#624C83"
        )
    )

    static let matteBlackLight = makeBuiltInVariant(
        base: matteBlack, id: "omarchy.matte-black.light", appearance: .light,
        summary: "Matte Black inverted into sharp ivory paper and amber signal ink.",
        palette: .init(
            accent: "#A85D00", selection: "#DDD8CE", muted: "#C9C3B8",
            background: "#F3F0EA", darkBackground: "#E7E2D8", darkerBackground: "#D8D1C5", lighterBackground: "#FFFEFB",
            foreground: "#292929", darkForeground: "#7A7772", lightForeground: "#4D4B48", brightForeground: "#111111",
            red: "#B43636", yellow: "#8A6500", orange: "#B55B00", green: "#6B6F12", cyan: "#496A70", blue: "#A85D00",
            magenta: "#8B4A65"
        )
    )
}
