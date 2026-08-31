import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let gruvbox = makeBuiltIn(
        id: "omarchy.gruvbox", name: "Gruvbox",
        summary: "Golden amber, dark walnut and a warm retro-console rhythm.",
        palette: .init(
            accent: "#E9B65D", selection: "#413225", muted: "#746047",
            background: "#231B16", darkBackground: "#19140F", lighterBackground: "#2E241B",
            foreground: "#F2DEB6", darkForeground: "#C7AD87",
            red: "#F59680", yellow: "#E9C46A", orange: "#F2B378", green: "#B7CD78",
            cyan: "#A9C0A0", magenta: "#E5A5B8",
            privacy: "#E9B65D", frame: "#E9B65D", wallet: "#B7CD78"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 196, navigationRowHeight: 40,
                panelPadding: 16, panelGap: 12),
            corners: .init(control: 6, hero: 8, navigation: 4),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.65, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "monospaced"),
            effects: .init(backdrop: "gradient", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let gruvboxLight = makeBuiltInVariant(
        base: gruvbox, id: "omarchy.gruvbox.light", appearance: .light,
        summary: "Parchment, ochre ink and compact, tactile controls.",
        palette: .init(
            accent: "#875214", selection: "#E9D7A6", muted: "#B4A079",
            background: "#FBF1C7", darkBackground: "#EBDCB2", lighterBackground: "#FFF8DA",
            foreground: "#3C2A1E", darkForeground: "#66513C",
            red: "#9D2530", yellow: "#785600", orange: "#93471B", green: "#4F641A",
            cyan: "#31664C", magenta: "#843958",
            privacy: "#875214", frame: "#875214", wallet: "#4F641A"
        )
    )
}
