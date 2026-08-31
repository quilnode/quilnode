import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let kanagawa = makeBuiltIn(
        id: "omarchy.kanagawa", name: "Kanagawa",
        summary: "Sumi ink, warm gold and wave-blue detail with sharp paper edges.",
        palette: .init(
            accent: "#E7C88E", selection: "#29374B", muted: "#57637A",
            background: "#171B25", darkBackground: "#10151E", lighterBackground: "#202A38",
            foreground: "#F0E2BE", darkForeground: "#C0B798",
            red: "#F0968F", yellow: "#E7C88E", orange: "#E9B193", green: "#B5C89A",
            cyan: "#95C6C4", magenta: "#C7AFE0",
            privacy: "#E7C88E", frame: "#E7C88E", wallet: "#95C6C4"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 3, hero: 4, navigation: 2),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.58, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "serif"),
            effects: .init(backdrop: "gradient", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let kanagawaLight = makeBuiltInVariant(
        base: kanagawa, id: "omarchy.kanagawa.light", appearance: .light,
        summary: "Warm washi paper, indigo ink and restrained gold accents.",
        palette: .init(
            accent: "#6B501E", selection: "#DED8C3", muted: "#ABA68D",
            background: "#F4EEDA", darkBackground: "#E9E0C4", lighterBackground: "#FFF9E9",
            foreground: "#32394F", darkForeground: "#5B5D59",
            red: "#9E3046", yellow: "#75551D", orange: "#884722", green: "#496032",
            cyan: "#315E66", magenta: "#634576",
            privacy: "#6B501E", frame: "#6B501E", wallet: "#315E66"
        )
    )
}
