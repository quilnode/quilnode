import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    // One family owns both palettes and a shared visual structure. Accent and
    // telemetry colors are text-safe adaptations, not terminal ANSI mappings.
    static let graphite = makeBuiltIn(
        id: "quil.graphite", name: "Graphite",
        summary: "Brushed silver, graphite-black surfaces and precision-cut controls.",
        palette: .init(
            accent: "#E0E7EE", selection: "#232D37", muted: "#4A5663",
            background: "#0B0D10", darkBackground: "#11151A", lighterBackground: "#171D24",
            foreground: "#F4F7FB", darkForeground: "#A5B1BE",
            red: "#FF8D9A", yellow: "#F4CE7F", orange: "#E0E7EE", green: "#7DE2AD",
            cyan: "#67D9EC", magenta: "#B8C4D1",
            privacy: "#E0E7EE", frame: "#E0E7EE", wallet: "#67D9EC"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 208, navigationRowHeight: 42,
                panelPadding: 20, panelGap: 16),
            corners: .init(control: 8, hero: 12, navigation: 6),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.55, selectedBorderWidth: 1,
                iconScale: 1, ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.94, elevatedOpacity: 1, borderOpacity: 0.65,
                heroAccentOpacity: 0.12),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "default"),
            effects: .init(backdrop: "solid", shadow: "none", accentTreatment: "solid", scene: "none")
        )
    )

    static let graphiteLight = makeBuiltInVariant(
        base: graphite, id: "quil.graphite.light", appearance: .light,
        summary: "Cool silver paper, dark steel accents and crisp cyan telemetry.",
        palette: .init(
            accent: "#263A50", selection: "#DFE6EE", muted: "#A6B2C0",
            background: "#F4F6F8", darkBackground: "#E8EDF2", lighterBackground: "#FFFFFF",
            foreground: "#17212C", darkForeground: "#526170",
            red: "#B82844", yellow: "#835000", orange: "#263A50", green: "#17653C",
            cyan: "#006879", magenta: "#4E6178",
            privacy: "#263A50", frame: "#263A50", wallet: "#006879"
        )
    )
}
