import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let tokyoNight = makeBuiltIn(
        id: "omarchy.tokyo-night", name: "Tokyo Night", summary: "Cool indigo night with crisp blue focus.",
        palette: .init(
            accent: "#7AA2F7", selection: "#292E42", muted: "#414868",
            background: "#1A1B26", darkBackground: "#13141C", darkerBackground: "#0E0E14", lighterBackground: "#24283B",
            foreground: "#A9B1D6", darkForeground: "#565F89", lightForeground: "#B4BEE6", brightForeground: "#C0CAF5",
            red: "#F7768E", yellow: "#E0AF68", orange: "#EB927B", green: "#9ECE6A", cyan: "#449DAB", blue: "#7AA2F7",
            magenta: "#AD8EE6"
        ),
        style: .init(
            spacing: .init(scale: 0.98, panelPadding: 17, panelGap: 14),
            corners: .init(control: 14, hero: 22, navigation: 8),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.22, selectedBorderWidth: 1, iconScale: 1,
                ringStyle: "gradient", ringThickness: 9),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.72, elevatedOpacity: 0.90, borderOpacity: 0.34,
                heroAccentOpacity: 0.12)
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
}
