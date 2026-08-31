import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let gruvbox = makeBuiltIn(
        id: "omarchy.gruvbox", name: "Gruvbox", summary: "Warm retro contrast with compact, grounded controls.",
        palette: .init(
            accent: "#7DAEA3", selection: "#504945", muted: "#665C54",
            background: "#282828", darkBackground: "#1E1E1E", darkerBackground: "#161616", lighterBackground: "#3C3836",
            foreground: "#D4BE98", darkForeground: "#7C6F64", lightForeground: "#BDAE93", brightForeground: "#D4BE98",
            red: "#EA6962", yellow: "#D8A657", orange: "#E1875C", green: "#A9B665", cyan: "#89B482", blue: "#7DAEA3",
            magenta: "#D3869B"
        ),
        style: .init(
            spacing: .init(
                scale: 0.94, sidebarExpandedWidth: 184, navigationRowHeight: 38, panelPadding: 16, panelGap: 12),
            corners: .init(control: 10, hero: 15, navigation: 7),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.28, selectedBorderWidth: 1, iconScale: 0.96,
                ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.88, elevatedOpacity: 1, borderOpacity: 0.42,
                heroAccentOpacity: 0.10),
            typography: .init(scale: 0.98, displayDesign: "default", dataDesign: "monospaced")
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
}
