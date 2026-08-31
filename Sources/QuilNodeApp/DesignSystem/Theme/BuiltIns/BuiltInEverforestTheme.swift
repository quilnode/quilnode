import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let everforest = makeBuiltIn(
        id: "omarchy.everforest", name: "Everforest", summary: "Organic green-gray surfaces with comfortable contrast.",
        palette: .init(
            accent: "#7FBBB3", selection: "#3D484D", muted: "#475258",
            background: "#2D353B", darkBackground: "#21272C", darkerBackground: "#181D20", lighterBackground: "#343F44",
            foreground: "#D3C6AA", darkForeground: "#4F585E", lightForeground: "#9DA9A0", brightForeground: "#D3C6AA",
            red: "#E67E80", yellow: "#DBBC7F", orange: "#E09D7F", green: "#A7C080", cyan: "#83C092", blue: "#7FBBB3",
            magenta: "#D699B6"
        ),
        style: .init(
            corners: .init(control: 15, hero: 20, navigation: 10),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.30, ringStyle: "solid", ringThickness: 9),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.78, elevatedOpacity: 0.94, borderOpacity: 0.32,
                heroAccentOpacity: 0.11), typography: .init(displayDesign: "rounded")
        )
    )

    static let everforestLight = makeBuiltInVariant(
        base: everforest, id: "omarchy.everforest.light", appearance: .light,
        summary: "Everforest Light's warm forest paper and soft green contrast.",
        palette: .init(
            accent: "#3A94C5", selection: "#E6E2CC", muted: "#D5D2BD",
            background: "#FDF6E3", darkBackground: "#F4F0D9", darkerBackground: "#E6E2CC", lighterBackground: "#FFFBF0",
            foreground: "#5C6A72", darkForeground: "#939F91", lightForeground: "#708089", brightForeground: "#3A444A",
            red: "#F85552", yellow: "#DFA000", orange: "#F57D26", green: "#8DA101", cyan: "#35A77C", blue: "#3A94C5",
            magenta: "#DF69BA"
        )
    )
}
