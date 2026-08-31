import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let kanagawa = makeBuiltIn(
        id: "omarchy.kanagawa", name: "Kanagawa", summary: "Ink-dark Japanese palette with warm paper typography.",
        palette: .init(
            accent: "#DCD7BA", selection: "#363646", muted: "#54546D",
            background: "#1F1F28", darkBackground: "#17171E", darkerBackground: "#111116", lighterBackground: "#223249",
            foreground: "#DCD7BA", darkForeground: "#727169", lightForeground: "#C8C093", brightForeground: "#DCD7BA",
            red: "#C34043", yellow: "#C0A36E", orange: "#C17158", green: "#76946A", cyan: "#6A9589", blue: "#7E9CD8",
            magenta: "#957FB8"
        ),
        style: .init(
            spacing: .init(scale: 0.98, panelPadding: 18, panelGap: 15),
            corners: .init(control: 8, hero: 13, navigation: 6),
            controls: .init(
                navigationSelectionStyle: "icon", selectionFillAlpha: 0.32, selectedBorderWidth: 1, iconScale: 1.08,
                ringStyle: "solid", ringThickness: 7),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.86, elevatedOpacity: 0.96, borderOpacity: 0.34,
                heroAccentOpacity: 0.08),
            typography: .init(scale: 1, displayDesign: "serif", dataDesign: "monospaced")
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
}
