import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let tokyoNight = makeBuiltIn(
        id: "omarchy.tokyo-night", name: "Tokyo Night",
        summary: "Electric cobalt, neon lilac and deep city-night indigo.",
        palette: .init(
            accent: "#82AAFF", selection: "#243056", muted: "#49567E",
            background: "#121526", darkBackground: "#0B1020", lighterBackground: "#19213B",
            foreground: "#E3EAFF", darkForeground: "#A3B2DA",
            red: "#FF93AB", yellow: "#F8CD88", orange: "#F8CD88", green: "#B5DB7D",
            cyan: "#7EE4F0", magenta: "#C7A0FA",
            privacy: "#82AAFF", frame: "#82AAFF", wallet: "#7EE4F0"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 10, hero: 18, navigation: 6),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.65, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "gradient", ringThickness: 8),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "default"),
            effects: .init(backdrop: "gradient", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let tokyoNightLight = makeBuiltInVariant(
        base: tokyoNight, id: "omarchy.tokyo-night.light", appearance: .light,
        summary: "Cobalt-blue ink on luminous periwinkle, with lilac highlights.",
        palette: .init(
            accent: "#2855C7", selection: "#DCE4FE", muted: "#A6B7EA",
            background: "#EFF2FF", darkBackground: "#E2E8FE", lighterBackground: "#F8FAFF",
            foreground: "#172C66", darkForeground: "#4B5C84",
            red: "#AF234C", yellow: "#79551C", orange: "#79551C", green: "#386027",
            cyan: "#12637B", magenta: "#7A39B3",
            privacy: "#2855C7", frame: "#2855C7", wallet: "#12637B"
        )
    )
}
