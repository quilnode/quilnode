import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let everforest = makeBuiltIn(
        id: "omarchy.everforest", name: "Everforest",
        summary: "Fern-green light, deep forest surfaces and organic rounded controls.",
        palette: .init(
            accent: "#B9DB7C", selection: "#2E4430", muted: "#587858",
            background: "#17271E", darkBackground: "#112118", lighterBackground: "#203529",
            foreground: "#EDF1D7", darkForeground: "#B6CBB5",
            red: "#F2A098", yellow: "#EBD184", orange: "#DBB585", green: "#B9DB7C",
            cyan: "#8FD5B6", magenta: "#E3B5C9",
            privacy: "#B9DB7C", frame: "#B9DB7C", wallet: "#8FD5B6"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 16, hero: 24, navigation: 12),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.62, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "gradient", ringThickness: 8),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "rounded"),
            effects: .init(backdrop: "gradient", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let everforestLight = makeBuiltInVariant(
        base: everforest, id: "omarchy.everforest.light", appearance: .light,
        summary: "Sunlit sage, leaf-green accents and warm botanical paper.",
        palette: .init(
            accent: "#3C681E", selection: "#D9E8C5", muted: "#9FB78C",
            background: "#F1F6E7", darkBackground: "#E1EDD7", lighterBackground: "#FCFFF4",
            foreground: "#2C422E", darkForeground: "#4F6650",
            red: "#A03D3E", yellow: "#76580C", orange: "#76580C", green: "#3C681E",
            cyan: "#286854", magenta: "#835177",
            privacy: "#3C681E", frame: "#3C681E", wallet: "#286854"
        )
    )
}
