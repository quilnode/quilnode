import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let nord = makeBuiltIn(
        id: "omarchy.nord", name: "Nord",
        summary: "Glacier-blue focus on deep polar surfaces, with clear arctic contrast.",
        palette: .init(
            accent: "#A9D7EF", selection: "#354B60", muted: "#59718B",
            background: "#242F40", darkBackground: "#1C2737", lighterBackground: "#2D3D50",
            foreground: "#EDF4FA", darkForeground: "#BDCDDC",
            red: "#F3A7AE", yellow: "#EDD49D", orange: "#EDD49D", green: "#C0D8A7",
            cyan: "#A7DDE3", magenta: "#D9B7D6",
            privacy: "#A9D7EF", frame: "#A9D7EF", wallet: "#A7DDE3"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 10, hero: 14, navigation: 8),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.6, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "default"),
            effects: .init(backdrop: "spotlight", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let nordLight = makeBuiltInVariant(
        base: nord, id: "omarchy.nord.light", appearance: .light,
        summary: "Frost-blue ink, snow-white cards and calm glacial surfaces.",
        palette: .init(
            accent: "#315B7E", selection: "#D5E5EF", muted: "#A5BDCD",
            background: "#EDF4F8", darkBackground: "#DCE9F1", lighterBackground: "#FBFDFF",
            foreground: "#253D52", darkForeground: "#456276",
            red: "#9E3E50", yellow: "#79581D", orange: "#79581D", green: "#44602C",
            cyan: "#276270", magenta: "#805178",
            privacy: "#315B7E", frame: "#315B7E", wallet: "#276270"
        )
    )
}
