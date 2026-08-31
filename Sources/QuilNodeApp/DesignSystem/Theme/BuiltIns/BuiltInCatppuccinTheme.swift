import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let catppuccin = makeBuiltIn(
        id: "omarchy.catppuccin", name: "Catppuccin",
        summary: "Candy pink, rich plum and playful rounded surfaces.",
        palette: .init(
            accent: "#FF8ED3", selection: "#51223F", muted: "#7E4569",
            background: "#271322", darkBackground: "#210C1D", lighterBackground: "#35182F",
            foreground: "#FFF1FB", darkForeground: "#E5B8D5",
            red: "#FFB2BE", yellow: "#FBE0A8", orange: "#F5BDA5", green: "#ADE3B0",
            cyan: "#8EDFE1", magenta: "#DDB2FF",
            privacy: "#FF8ED3", frame: "#FF8ED3", wallet: "#BFE6F2"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 22, hero: 32, navigation: 18),
            controls: .init(
                navigationSelectionStyle: "capsule", selectionFillAlpha: 0.72, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "gradient", ringThickness: 8),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "rounded"),
            effects: .init(backdrop: "gradient", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let catppuccinLight = makeBuiltInVariant(
        base: catppuccin, id: "omarchy.catppuccin.light", appearance: .light,
        summary: "Vivid pink on strawberry-milk surfaces, with soft lilac accents.",
        palette: .init(
            accent: "#B31475", selection: "#F8D3EA", muted: "#D797BF",
            background: "#FFF1F8", darkBackground: "#FFE0F1", lighterBackground: "#FFFAFD",
            foreground: "#4D123A", darkForeground: "#794563",
            red: "#A32449", yellow: "#7D520B", orange: "#7D520B", green: "#27613E",
            cyan: "#1D6075", magenta: "#762B9C",
            privacy: "#B31475", frame: "#B31475", wallet: "#672795"
        )
    )
}
