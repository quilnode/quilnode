import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // Inspired by quilibrium.com and docs.quilibrium.com: rose/burgundy
    // atmosphere, neutral content surfaces, and readable geometric headings.
    // Text accents are appearance-specific; semantic status colors stay distinct.
    static let classic = makeBuiltIn(
        id: "quil.classic", name: "Quilibrium", appearance: .dark,
        summary: "Quilibrium-inspired charcoal, burgundy atmosphere, and protocol-pink accents.",
        familyID: "quil.classic", author: "QuilNode", tags: ["quilibrium", "classic", "protocol", "dark"],
        palette: .init(
            accent: "#FF217B", selection: "#40001B", muted: "#5E4F56",
            background: "#111111", darkBackground: "#111111", lighterBackground: "#1B181A",
            foreground: "#F0E9E4", darkForeground: "#C5BBC0", brightForeground: "#FFFFFF",
            red: "#FF7690", yellow: "#F6D995", orange: "#FFAB73", green: "#55C67A",
            cyan: "#79B1E8", blue: "#79B1E8", magenta: "#B8A0F2",
            privacy: "#FF659F", frame: "#FF659F", wallet: "#79B1E8"
        ),
        style: quilibriumStyle
    )

    static let classicLight = makeBuiltIn(
        id: "quil.classic.light", name: "Quilibrium", appearance: .light,
        summary: "Quilibrium-inspired white surfaces, blush accents, and burgundy text.",
        familyID: "quil.classic", author: "QuilNode", tags: ["quilibrium", "classic", "protocol", "light"],
        palette: .init(
            accent: "#C90053", selection: "#FFE6F0", muted: "#C9B6BE",
            background: "#F8F8F8", darkBackground: "#FFFFFF", lighterBackground: "#FFFFFF",
            foreground: "#40001B", darkForeground: "#69515C", brightForeground: "#25000F",
            red: "#BA2647", yellow: "#895A00", orange: "#A64700", green: "#186637",
            cyan: "#285F91", blue: "#285F91", magenta: "#6330CA",
            privacy: "#C90053", frame: "#C90053", wallet: "#285F91"
        ),
        style: quilibriumStyle
    )

    private static let quilibriumStyle = QuilThemeStyleDocument(
        spacing: .init(
            scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42, panelPadding: 19, panelGap: 16),
        corners: .init(control: 12, hero: 16, navigation: 8),
        controls: .init(
            navigationSelectionStyle: "row", selectionFillAlpha: 0.24, selectedBorderWidth: 1,
            iconScale: 1, ringStyle: "solid", ringThickness: 8),
        surfaces: .init(
            treatment: "solid", borderStyle: "solid", surfaceOpacity: 1, elevatedOpacity: 1,
            borderOpacity: 0.45, heroAccentOpacity: 0.06),
        typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "default"),
        effects: .init(
            backdrop: "gradient", decoration: "none", decorationOpacity: 0, shadow: "none", shadowOpacity: 0,
            accentTreatment: "solid", motionScale: 1, scene: "none", sceneOpacity: 0),
        composition: .init(
            pageHeader: "native", sidebarBrand: "tile", hero: "topology", metricStrip: "ruled", panel: "card",
            badge: "label", dataLabels: "human")
    )
}
