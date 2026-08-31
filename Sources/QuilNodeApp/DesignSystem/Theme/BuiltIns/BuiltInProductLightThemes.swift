import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let quilNodeLight = makeBuiltIn(
        id: "quilnode.default.light", name: "QuilNode", appearance: .light,
        summary: "QuilNode's local operations console translated into a crisp daylight workspace.",
        familyID: "quilnode.default", author: "QuilNode", tags: ["quilnode", "operations", "topology", "light"],
        palette: .init(
            accent: "#087DBF", selection: "#DCEFFE", muted: "#A7BCCB",
            background: "#F5FAFD", darkBackground: "#EAF4FA", darkerBackground: "#DDEBF3", lighterBackground: "#FFFFFF",
            foreground: "#0A1D2B", darkForeground: "#6C7F8D", lightForeground: "#3F5666", brightForeground: "#02070D",
            red: "#C93F58", yellow: "#A96809", orange: "#BB6900", green: "#187846", cyan: "#087DBF", blue: "#006FB8",
            magenta: "#6657C8",
            privacy: "#6657C8", frame: "#006FB8", wallet: "#A96809"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 194, navigationRowHeight: 40, panelPadding: 19, panelGap: 16),
            corners: .init(control: 8, hero: 10, navigation: 5),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.68, selectedBorderWidth: 1, iconScale: 1,
                ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", borderStyle: "solid", surfaceOpacity: 0.90, elevatedOpacity: 1, borderOpacity: 0.66,
                heroAccentOpacity: 0.07),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced", heroDesign: "monospaced"),
            effects: .init(
                backdrop: "solid", decoration: "none", decorationOpacity: 0, shadow: "none", shadowOpacity: 0,
                accentTreatment: "solid", motionScale: 1, scene: "none", sceneOpacity: 0),
            composition: .init(
                pageHeader: "native", sidebarBrand: "tile", hero: "topology", metricStrip: "ruled", panel: "card",
                badge: "label", dataLabels: "human")
        )
    )

    static let classicLight = makeBuiltIn(
        id: "quil.classic.light", name: "Quilibrium", appearance: .light,
        summary: "The original Quilibrium identity translated into warm cream paper and burgundy ink.",
        familyID: "quil.classic", author: "QuilNode", tags: ["quilibrium", "classic", "protocol", "light"],
        palette: .init(
            accent: "#D90058", selection: "#FFE6F0", muted: "#C9B6BE",
            background: "#F0E9E4", darkBackground: "#E7DDD8", darkerBackground: "#D8CBC5", lighterBackground: "#FFFFFF",
            foreground: "#40001B", darkForeground: "#75636B", lightForeground: "#60434F", brightForeground: "#25000F",
            red: "#D92C52", yellow: "#A56D00", orange: "#D85000", green: "#167D32", cyan: "#1477A8",
            blue: "#286FC0", magenta: "#6330CA",
            privacy: "#D90058", frame: "#D85000", wallet: "#286FC0"
        ),
        style: .init(
            spacing: .init(
                scale: 1, sidebarExpandedWidth: 194, navigationRowHeight: 40, panelPadding: 19, panelGap: 16),
            corners: .init(control: 8, hero: 10, navigation: 5),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.30, selectedBorderWidth: 1, iconScale: 1,
                ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", borderStyle: "solid", surfaceOpacity: 0.90, elevatedOpacity: 1, borderOpacity: 0.66,
                heroAccentOpacity: 0.07),
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced"),
            effects: .init(
                backdrop: "solid", decoration: "none", decorationOpacity: 0, shadow: "none", shadowOpacity: 0,
                accentTreatment: "solid", motionScale: 1, scene: "none", sceneOpacity: 0),
            composition: .init(
                pageHeader: "native", sidebarBrand: "tile", hero: "topology", metricStrip: "ruled", panel: "card",
                badge: "label", dataLabels: "human")
        )
    )
}
