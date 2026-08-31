import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let matteBlack = makeBuiltIn(
        id: "omarchy.matte-black", name: "Matte Black", summary: "Near-black, sharp-edged, amber signal console.",
        palette: .init(
            accent: "#E68E0D", selection: "#2A2A2A", muted: "#333333",
            background: "#121212", darkBackground: "#0D0D0D", darkerBackground: "#090909", lighterBackground: "#1E1E1E",
            foreground: "#BEBEBE", darkForeground: "#555555", lightForeground: "#8A8A8D", brightForeground: "#BEBEBE",
            red: "#D35F5F", yellow: "#B91C1C", orange: "#C63D3D", green: "#FFC107", cyan: "#BEBEBE", blue: "#E68E0D",
            magenta: "#D35F5F"
        ),
        style: .init(
            spacing: .init(
                scale: 0.92, sidebarExpandedWidth: 182, navigationRowHeight: 37, panelPadding: 15, panelGap: 10),
            corners: .init(control: 6, hero: 9, navigation: 5),
            controls: .init(
                navigationSelectionStyle: "icon", selectionFillAlpha: 0.36, selectedBorderWidth: 1, iconScale: 0.94,
                ringStyle: "solid", ringThickness: 6),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 1, elevatedOpacity: 1, borderOpacity: 0.65, heroAccentOpacity: 0.07),
            typography: .init(scale: 0.96, displayDesign: "monospaced", dataDesign: "monospaced")
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
