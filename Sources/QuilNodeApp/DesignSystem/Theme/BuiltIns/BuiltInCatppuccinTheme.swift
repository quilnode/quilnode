import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let catppuccin = makeBuiltIn(
        id: "omarchy.catppuccin", name: "Catppuccin", summary: "Soft mocha surfaces with playful pastel status colors.",
        palette: .init(
            accent: "#89B4FA", selection: "#45475A", muted: "#585B70",
            background: "#1E1E2E", darkBackground: "#161622", darkerBackground: "#101019", lighterBackground: "#313244",
            foreground: "#CDD6F4", darkForeground: "#6C7086", lightForeground: "#BAC2DE", brightForeground: "#CDD6F4",
            red: "#F38BA8", yellow: "#F9E2AF", orange: "#F6B6AB", green: "#A6E3A1", cyan: "#94E2D5", blue: "#89B4FA",
            magenta: "#F5C2E7"
        ),
        style: .init(
            spacing: .init(scale: 1.02, panelPadding: 19, panelGap: 16),
            corners: .init(control: 20, hero: 28, navigation: 14),
            controls: .init(
                navigationSelectionStyle: "capsule", selectionFillAlpha: 0.24, iconScale: 1.04, ringStyle: "gradient",
                ringThickness: 10),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.76, elevatedOpacity: 0.92, borderOpacity: 0.28,
                heroAccentOpacity: 0.14)
        )
    )

    static let catppuccinLight = makeBuiltInVariant(
        base: catppuccin, id: "omarchy.catppuccin.light", appearance: .light,
        summary: "Catppuccin Latte's warm paper base and saturated pastel accents.",
        palette: .init(
            accent: "#1E66F5", selection: "#CCD0DA", muted: "#BCC0CC",
            background: "#EFF1F5", darkBackground: "#E6E9EF", darkerBackground: "#DCE0E8", lighterBackground: "#FFFFFF",
            foreground: "#4C4F69", darkForeground: "#8C8FA1", lightForeground: "#6C6F85", brightForeground: "#303446",
            red: "#D20F39", yellow: "#DF8E1D", orange: "#FE640B", green: "#40A02B", cyan: "#179299", blue: "#1E66F5",
            magenta: "#8839EF"
        )
    )
}
