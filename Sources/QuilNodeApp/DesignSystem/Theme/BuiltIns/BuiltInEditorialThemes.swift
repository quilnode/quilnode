import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    /// Based on Nous Research's cyan-on-white editorial grid, monospace output
    /// labels, seed metadata, and dashed technical separators.
    static let nousResearch = makeBuiltIn(
        id: "research.nous", name: "Nous // OUTPUT", appearance: .light,
        summary: "Open-source research rendered as a cyan terminal-editorial system.",
        author: "QuilNode · Nous Research-inspired", tags: ["research", "open-source", "terminal", "light"],
        palette: .init(
            accent: "#0171A9", selection: "#DAE3E8", muted: "#9CBAC8",
            background: "#FFFFFF", darkBackground: "#F5F9FB", darkerBackground: "#E0E8EC", lighterBackground: "#F7FBFC",
            foreground: "#013B4F", darkForeground: "#276285", lightForeground: "#2D3D47", brightForeground: "#010A26",
            red: "#D9534F", yellow: "#C9952F", orange: "#E68A3C", green: "#4E9F70", cyan: "#0171A9", blue: "#3430F7",
            magenta: "#6C55B8",
            privacy: "#3430F7", frame: "#0171A9", wallet: "#00547E"
        ),
        style: .init(
            spacing: .init(
                scale: 0.97, sidebarExpandedWidth: 198, navigationRowHeight: 39, panelPadding: 21, panelGap: 16),
            corners: .init(control: 0, hero: 0, navigation: 0),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.36, selectedBorderWidth: 1, iconScale: 0.96,
                ringStyle: "solid", ringThickness: 7),
            surfaces: .init(
                treatment: "solid", borderStyle: "dashed", surfaceOpacity: 0.96, elevatedOpacity: 1,
                borderOpacity: 0.70, heroAccentOpacity: 0.055),
            typography: .init(scale: 0.98, displayDesign: "monospaced", dataDesign: "monospaced"),
            effects: .init(
                backdrop: "solid", decoration: "grid", decorationOpacity: 0.035, shadow: "none", shadowOpacity: 0,
                accentTreatment: "solid", motionScale: 0.85, scene: "orbital", sceneOpacity: 0.18),
            composition: .init(
                pageHeader: "output", sidebarBrand: "wordmark", hero: "terminal", metricStrip: "cells",
                panel: "terminal", badge: "label", dataLabels: "terminal")
        )
    )

    static let nousResearchDark = makeBuiltIn(
        id: "research.nous.dark", name: "Nous // OUTPUT", appearance: .dark,
        summary: "Nous's open research grid shifted into a deep-navy terminal mode.",
        familyID: "research.nous", author: "QuilNode · Nous Research-inspired",
        tags: ["research", "open-source", "terminal", "dark"],
        palette: .init(
            accent: "#40B9EF", selection: "#0A2D49", muted: "#1B5673",
            background: "#010A26", darkBackground: "#020719", darkerBackground: "#010515", lighterBackground: "#081632",
            foreground: "#D6F2FF", darkForeground: "#77B9D7", lightForeground: "#A9DDF2", brightForeground: "#FFFFFF",
            red: "#FF7B80", yellow: "#E8C568", orange: "#F0A55A", green: "#71D6A0", cyan: "#40B9EF", blue: "#7B78FF",
            magenta: "#A78BFA",
            privacy: "#7B78FF", frame: "#40B9EF", wallet: "#79D5FF"
        ),
        style: .init(
            spacing: .init(
                scale: 0.97, sidebarExpandedWidth: 198, navigationRowHeight: 39, panelPadding: 21, panelGap: 16),
            corners: .init(control: 0, hero: 0, navigation: 0),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.38, selectedBorderWidth: 1, iconScale: 0.96,
                ringStyle: "solid", ringThickness: 7),
            surfaces: .init(
                treatment: "solid", borderStyle: "dashed", surfaceOpacity: 0.96, elevatedOpacity: 1,
                borderOpacity: 0.78, heroAccentOpacity: 0.07),
            typography: .init(scale: 0.98, displayDesign: "monospaced", dataDesign: "monospaced"),
            effects: .init(
                backdrop: "solid", decoration: "grid", decorationOpacity: 0.045, shadow: "none", shadowOpacity: 0,
                accentTreatment: "solid", motionScale: 0.85, scene: "orbital", sceneOpacity: 0.24),
            composition: .init(
                pageHeader: "output", sidebarBrand: "wordmark", hero: "terminal", metricStrip: "cells",
                panel: "terminal", badge: "label", dataLabels: "terminal")
        )
    )

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
            typography: .init(scale: 1, displayDesign: "default", dataDesign: "monospaced"),
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
