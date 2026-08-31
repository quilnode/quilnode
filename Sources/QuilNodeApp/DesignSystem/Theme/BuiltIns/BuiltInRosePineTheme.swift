import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let rosePine = makeBuiltIn(
        id: "omarchy.rose-pine", name: "Rosé Pine Dawn", appearance: .light,
        summary: "A warm daylight workspace with understated rose accents.",
        palette: .init(
            accent: "#56949F", selection: "#DFDAD9", muted: "#CECACD",
            background: "#FAF4ED", darkBackground: "#EDE7E1", darkerBackground: "#E1DBD5", lighterBackground: "#F2E9E1",
            foreground: "#575279", darkForeground: "#9893A5", lightForeground: "#6E6A86", brightForeground: "#575279",
            red: "#B4637A", yellow: "#EA9D34", orange: "#CF8057", green: "#286983", cyan: "#D7827E", blue: "#56949F",
            magenta: "#907AA9"
        ),
        style: .init(
            spacing: .init(scale: 1.03, panelPadding: 20, panelGap: 17),
            corners: .init(control: 18, hero: 27, navigation: 12),
            controls: .init(
                navigationSelectionStyle: "capsule", selectionFillAlpha: 0.38, selectedBorderWidth: 1, iconScale: 1.02,
                ringStyle: "gradient", ringThickness: 9),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.90, elevatedOpacity: 1, borderOpacity: 0.55,
                heroAccentOpacity: 0.10),
            typography: .init(scale: 1.01, displayDesign: "rounded")
        )
    )

    static let rosePineDark = makeBuiltInVariant(
        base: rosePine, id: "omarchy.rose-pine.dark", appearance: .dark,
        summary: "Rosé Pine Moon's deep plum base and soft Soho accents.",
        palette: .init(
            accent: "#9CCFD8", selection: "#44415A", muted: "#393552",
            background: "#232136", darkBackground: "#1D1A2E", darkerBackground: "#171522", lighterBackground: "#2A273F",
            foreground: "#E0DEF4", darkForeground: "#6E6A86", lightForeground: "#908CAA", brightForeground: "#F5F2FF",
            red: "#EB6F92", yellow: "#F6C177", orange: "#EA9A97", green: "#3E8FB0", cyan: "#9CCFD8", blue: "#56949F",
            magenta: "#C4A7E7"
        )
    )
}
