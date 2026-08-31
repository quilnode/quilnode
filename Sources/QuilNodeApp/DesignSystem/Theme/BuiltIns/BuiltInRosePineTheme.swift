import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let rosePine = makeBuiltIn(
        id: "omarchy.rose-pine", name: "Rosé Pine", appearance: .light,
        summary: "Rose ink on warm cream, with elegant paper-like surfaces.",
        palette: .init(
            accent: "#9D3D5E", selection: "#EBDCD9", muted: "#BCA3AE",
            background: "#FAF4ED", darkBackground: "#F1E4DE", lighterBackground: "#FFF9F3",
            foreground: "#49354F", darkForeground: "#715768",
            red: "#9B304F", yellow: "#835718", orange: "#9D3D5E", green: "#3D674E",
            cyan: "#33697B", magenta: "#725198",
            privacy: "#9D3D5E", frame: "#9D3D5E", wallet: "#33697B"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 18, hero: 26, navigation: 14),
            controls: .init(
                navigationSelectionStyle: "capsule", selectionFillAlpha: 0.62, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "gradient", ringThickness: 8),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "serif"),
            effects: .init(backdrop: "spotlight", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let rosePineDark = makeBuiltInVariant(
        base: rosePine, id: "omarchy.rose-pine.dark", appearance: .dark,
        summary: "Rose-gold accents, plum ink and soft editorial typography.",
        palette: .init(
            accent: "#EEAAC1", selection: "#403048", muted: "#775F7D",
            background: "#211B2B", darkBackground: "#1B1523", lighterBackground: "#2D233A",
            foreground: "#F5E6F0", darkForeground: "#CDB6CB",
            red: "#F99BAA", yellow: "#F6C177", orange: "#EEAAC1", green: "#ACD2B5",
            cyan: "#9CCFD8", magenta: "#CCB2EC",
            privacy: "#EEAAC1", frame: "#EEAAC1", wallet: "#9CCFD8"
        )
    )
}
