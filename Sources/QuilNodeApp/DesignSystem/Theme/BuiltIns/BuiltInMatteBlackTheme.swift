import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let matteBlack = makeBuiltIn(
        id: "omarchy.matte-black", name: "Matte Black",
        summary: "True black, bright amber and an uncompromising instrument-panel finish.",
        palette: .init(
            accent: "#FFD166", selection: "#24211B", muted: "#58554B",
            background: "#08090B", darkBackground: "#000000", lighterBackground: "#121417",
            foreground: "#F4F4F2", darkForeground: "#B0B0AA",
            red: "#FF9393", yellow: "#FFD166", orange: "#F1B16F", green: "#98DDA5",
            cyan: "#C8D5D8", magenta: "#CAC8C0",
            privacy: "#FFD166", frame: "#FFD166", wallet: "#C8D5D8"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 196, navigationRowHeight: 40,
                panelPadding: 16, panelGap: 12),
            corners: .init(control: 2, hero: 4, navigation: 2),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.8, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "monospaced"),
            effects: .init(backdrop: "solid", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let matteBlackLight = makeBuiltInVariant(
        base: matteBlack, id: "omarchy.matte-black.light", appearance: .light,
        summary: "Sharp black type on clean white, with focused amber signals.",
        palette: .init(
            accent: "#805400", selection: "#E6E3D9", muted: "#A8A79A",
            background: "#FAFAF8", darkBackground: "#ECECE8", lighterBackground: "#FFFFFF",
            foreground: "#171713", darkForeground: "#59594F",
            red: "#A72E3A", yellow: "#805400", orange: "#805400", green: "#2C6436",
            cyan: "#344E58", magenta: "#5E594B",
            privacy: "#805400", frame: "#805400", wallet: "#344E58"
        )
    )
}
