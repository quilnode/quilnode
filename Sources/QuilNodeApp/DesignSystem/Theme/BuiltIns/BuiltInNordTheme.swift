import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let nord = makeBuiltIn(
        id: "omarchy.nord", name: "Nord", summary: "Calm arctic blues and disciplined low-contrast panels.",
        palette: .init(
            accent: "#81A1C1", selection: "#434C5E", muted: "#4C566A",
            background: "#2E3440", darkBackground: "#222730", darkerBackground: "#191C23", lighterBackground: "#3B4252",
            foreground: "#D8DEE9", darkForeground: "#667080", lightForeground: "#ADB5C4", brightForeground: "#D8DEE9",
            red: "#BF616A", yellow: "#EBCB8B", orange: "#D5967A", green: "#A3BE8C", cyan: "#88C0D0", blue: "#81A1C1",
            magenta: "#B48EAD"
        ),
        style: .init(
            corners: .init(control: 12, hero: 18, navigation: 8),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.32, selectedBorderWidth: 1, ringStyle: "solid",
                ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.82, elevatedOpacity: 0.96, borderOpacity: 0.38,
                heroAccentOpacity: 0.09),
            typography: .init(displayDesign: "default")
        )
    )

    static let nordLight = makeBuiltInVariant(
        base: nord, id: "omarchy.nord.light", appearance: .light,
        summary: "Nord Snow Storm: arctic paper with Frost and Aurora signals.",
        palette: .init(
            accent: "#5E81AC", selection: "#D8DEE9", muted: "#C8D0DB",
            background: "#ECEFF4", darkBackground: "#E5E9F0", darkerBackground: "#D8DEE9", lighterBackground: "#FFFFFF",
            foreground: "#2E3440", darkForeground: "#7B8494", lightForeground: "#4C566A", brightForeground: "#242933",
            red: "#BF616A", yellow: "#B58A37", orange: "#D08770", green: "#668A50", cyan: "#2E7E91", blue: "#5E81AC",
            magenta: "#9A6F93"
        )
    )
}
