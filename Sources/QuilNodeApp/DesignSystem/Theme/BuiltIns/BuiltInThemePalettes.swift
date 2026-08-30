import SwiftUI

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilTheme {
    static let quilNode = QuilTheme(
        id: "quilnode.default", familyID: "quilnode.default", name: "QuilNode", author: "QuilNode", version: "1.0.0",
        appearance: .dark, summary: "QuilNode's focused local operations console with electric-blue telemetry.",
        tags: ["quilnode", "operations", "topology", "dark"],
        colors: .init(
            accent: Color(themeValue: "#22A6FF", fallback: .accentColor),
            accentSecondary: Color(themeValue: "#785CFF", fallback: .purple),
            selection: Color(themeValue: "#0B3B59", fallback: .gray),
            muted: Color(themeValue: "#183044", fallback: .gray),
            success: Color(themeValue: "#4BD478", fallback: .green),
            warning: Color(themeValue: "#FF991F", fallback: .orange),
            danger: Color(themeValue: "#FF5C76", fallback: .red),
            info: Color(themeValue: "#22A6FF", fallback: .blue),
            privacy: Color(themeValue: "#785CFF", fallback: .purple),
            frame: Color(themeValue: "#22A6FF", fallback: .blue),
            wallet: Color(themeValue: "#FF991F", fallback: .orange),
            canvas: Color(themeValue: "#02070D", fallback: .black),
            sidebar: Color(themeValue: "#040A11", fallback: .black),
            surface: Color(themeValue: "#06101A", fallback: .gray),
            surfaceElevated: Color(themeValue: "#081521", fallback: .gray),
            border: Color(themeValue: "#183044", fallback: .gray),
            primaryText: Color(themeValue: "#F4F7FA", fallback: .primary),
            secondaryText: Color(themeValue: "#98A8B7", fallback: .secondary)
        ),
        metrics: .init(
            sidebarCollapsedWidth: 72, sidebarExpandedWidth: 208, navigationRowHeight: 42,
            controlCornerRadius: 8, heroCornerRadius: 10, spacingScale: 1, borderWidth: 1,
            navigationCornerRadius: 5, panelPadding: 19, panelGap: 16
        ),
        typography: .init(scale: 1, displayDesign: .default, dataDesign: .monospaced),
        components: .init(
            navigationSelection: .row, ringStyle: .solid, surfaceTreatment: .solid,
            backdropStyle: .solid, shadowStyle: .none, accentTreatment: .solid,
            selectionFillAlpha: 0.68, selectedBorderWidth: 1, iconScale: 1, ringThickness: 8,
            surfaceOpacity: 0.88, elevatedOpacity: 0.98, borderOpacity: 0.72, heroAccentOpacity: 0.08,
            sceneOpacity: 1, shadowOpacity: 0
        ),
        recipes: .init(hero: .topology, metricStrip: .ruled, badge: .label),
        isBuiltIn: true
    )

    static let classic = QuilTheme(
        id: "quil.classic", familyID: "quil.classic", name: "Quilibrium", author: "QuilNode", version: "1.0.0",
        appearance: .dark, summary: "The original Quilibrium burgundy, cream, and protocol-pink palette.",
        tags: ["quilibrium", "classic", "protocol", "dark"],
        colors: .init(
            accent: Color(themeValue: "#FF056D", fallback: .accentColor),
            accentSecondary: Color(themeValue: "#6330CA", fallback: .purple),
            selection: Color(themeValue: "#40001B", fallback: .gray),
            muted: Color(themeValue: "#5E4F56", fallback: .gray),
            success: Color(themeValue: "#22A941", fallback: .green),
            warning: Color(themeValue: "#F6E2B3", fallback: .yellow),
            danger: Color(themeValue: "#FF4D6D", fallback: .red),
            info: Color(themeValue: "#58A7FF", fallback: .blue),
            privacy: Color(themeValue: "#FF056D", fallback: .pink),
            frame: Color(themeValue: "#FF6000", fallback: .orange),
            wallet: Color(themeValue: "#58A7FF", fallback: .blue),
            canvas: Color(themeValue: "#111111", fallback: .black),
            sidebar: Color(themeValue: "#0D0D0D", fallback: .black),
            surface: Color(themeValue: "#242526", fallback: .gray),
            surfaceElevated: Color(themeValue: "#40001B", fallback: .gray),
            border: Color(themeValue: "#5E4F56", fallback: .gray),
            primaryText: Color(themeValue: "#F0E9E4", fallback: .primary),
            secondaryText: Color(themeValue: "#BEB8B4", fallback: .secondary)
        ),
        metrics: .init(
            sidebarCollapsedWidth: 72, sidebarExpandedWidth: 208, navigationRowHeight: 42,
            controlCornerRadius: 8, heroCornerRadius: 10, spacingScale: 1, borderWidth: 1,
            navigationCornerRadius: 5, panelPadding: 19, panelGap: 16
        ),
        typography: .init(scale: 1, displayDesign: .default, dataDesign: .monospaced),
        components: .init(
            navigationSelection: .row, ringStyle: .solid, surfaceTreatment: .solid,
            backdropStyle: .solid, shadowStyle: .none, accentTreatment: .solid,
            selectionFillAlpha: 0.30, selectedBorderWidth: 1, iconScale: 1, ringThickness: 8,
            surfaceOpacity: 0.88, elevatedOpacity: 0.98, borderOpacity: 0.72, heroAccentOpacity: 0.08,
            sceneOpacity: 0, shadowOpacity: 0
        ),
        recipes: .init(hero: .topology, metricStrip: .ruled, badge: .label),
        isBuiltIn: true
    )

    static let graphite = makeBuiltIn(
        id: "quil.graphite", name: "Graphite", summary: "Restrained graphite glass with cyan telemetry.",
        palette: .init(
            accent: "#63D7E8", selection: "#30383F", muted: "#53606A",
            background: "#121416", darkBackground: "#191D21", darkerBackground: "#0D0F11", lighterBackground: "#252B30",
            foreground: "#EEF2F3", darkForeground: "#849096", lightForeground: "#C8D0D3", brightForeground: "#FFFFFF",
            red: "#FF6B6B", yellow: "#E7C86E", orange: "#E99D67", green: "#6ED6A0", cyan: "#63D7E8", blue: "#8D8AFF",
            magenta: "#C782FF"
        ),
        style: .init(
            surfaces: .init(treatment: "material", surfaceOpacity: 0.62, elevatedOpacity: 0.84, borderOpacity: 0.20))
    )

    static let tokyoNight = makeBuiltIn(
        id: "omarchy.tokyo-night", name: "Tokyo Night", summary: "Cool indigo night with crisp blue focus.",
        palette: .init(
            accent: "#7AA2F7", selection: "#292E42", muted: "#414868",
            background: "#1A1B26", darkBackground: "#13141C", darkerBackground: "#0E0E14", lighterBackground: "#24283B",
            foreground: "#A9B1D6", darkForeground: "#565F89", lightForeground: "#B4BEE6", brightForeground: "#C0CAF5",
            red: "#F7768E", yellow: "#E0AF68", orange: "#EB927B", green: "#9ECE6A", cyan: "#449DAB", blue: "#7AA2F7",
            magenta: "#AD8EE6"
        ),
        style: .init(
            spacing: .init(scale: 0.98, panelPadding: 17, panelGap: 14),
            corners: .init(control: 14, hero: 22, navigation: 8),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.22, selectedBorderWidth: 1, iconScale: 1,
                ringStyle: "gradient", ringThickness: 9),
            surfaces: .init(
                treatment: "tinted", surfaceOpacity: 0.72, elevatedOpacity: 0.90, borderOpacity: 0.34,
                heroAccentOpacity: 0.12)
        )
    )

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

    static let gruvbox = makeBuiltIn(
        id: "omarchy.gruvbox", name: "Gruvbox", summary: "Warm retro contrast with compact, grounded controls.",
        palette: .init(
            accent: "#7DAEA3", selection: "#504945", muted: "#665C54",
            background: "#282828", darkBackground: "#1E1E1E", darkerBackground: "#161616", lighterBackground: "#3C3836",
            foreground: "#D4BE98", darkForeground: "#7C6F64", lightForeground: "#BDAE93", brightForeground: "#D4BE98",
            red: "#EA6962", yellow: "#D8A657", orange: "#E1875C", green: "#A9B665", cyan: "#89B482", blue: "#7DAEA3",
            magenta: "#D3869B"
        ),
        style: .init(
            spacing: .init(
                scale: 0.94, sidebarExpandedWidth: 184, navigationRowHeight: 38, panelPadding: 16, panelGap: 12),
            corners: .init(control: 10, hero: 15, navigation: 7),
            controls: .init(
                navigationSelectionStyle: "row", selectionFillAlpha: 0.28, selectedBorderWidth: 1, iconScale: 0.96,
                ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.88, elevatedOpacity: 1, borderOpacity: 0.42,
                heroAccentOpacity: 0.10),
            typography: .init(scale: 0.98, displayDesign: "default", dataDesign: "monospaced")
        )
    )

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

    static let kanagawa = makeBuiltIn(
        id: "omarchy.kanagawa", name: "Kanagawa", summary: "Ink-dark Japanese palette with warm paper typography.",
        palette: .init(
            accent: "#DCD7BA", selection: "#363646", muted: "#54546D",
            background: "#1F1F28", darkBackground: "#17171E", darkerBackground: "#111116", lighterBackground: "#223249",
            foreground: "#DCD7BA", darkForeground: "#727169", lightForeground: "#C8C093", brightForeground: "#DCD7BA",
            red: "#C34043", yellow: "#C0A36E", orange: "#C17158", green: "#76946A", cyan: "#6A9589", blue: "#7E9CD8",
            magenta: "#957FB8"
        ),
        style: .init(
            spacing: .init(scale: 0.98, panelPadding: 18, panelGap: 15),
            corners: .init(control: 8, hero: 13, navigation: 6),
            controls: .init(
                navigationSelectionStyle: "icon", selectionFillAlpha: 0.32, selectedBorderWidth: 1, iconScale: 1.08,
                ringStyle: "solid", ringThickness: 7),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 0.86, elevatedOpacity: 0.96, borderOpacity: 0.34,
                heroAccentOpacity: 0.08),
            typography: .init(scale: 1, displayDesign: "serif", dataDesign: "monospaced")
        )
    )

    static let matteBlack = makeBuiltIn(
        id: "omarchy.matte-black", name: "Matte Black", summary: "Near-black, sharp-edged, amber signal console.",
        palette: .init(
            accent: "#E68E0D", selection: "#2A2A2A", muted: "#333333",
            background: "#121212", darkBackground: "#0D0D0D", darkerBackground: "#090909", lighterBackground: "#1E1E1E",
            foreground: "#BEBEBE", darkForeground: "#555555", lightForeground: "#8A8A8D", brightForeground: "#BEBEBE",
            red: "#D35F5F", yellow: "#B91C1C", orange: "#C63D3D", green: "#FFC107", cyan: "#BEBEBE", blue: "#E68E0D",
            magenta: "#D35F5F"
        ),
        style: .init(
            spacing: .init(
                scale: 0.92, sidebarExpandedWidth: 182, navigationRowHeight: 37, panelPadding: 15, panelGap: 10),
            corners: .init(control: 6, hero: 9, navigation: 5),
            controls: .init(
                navigationSelectionStyle: "icon", selectionFillAlpha: 0.36, selectedBorderWidth: 1, iconScale: 0.94,
                ringStyle: "solid", ringThickness: 6),
            surfaces: .init(
                treatment: "solid", surfaceOpacity: 1, elevatedOpacity: 1, borderOpacity: 0.65, heroAccentOpacity: 0.07),
            typography: .init(scale: 0.96, displayDesign: "monospaced", dataDesign: "monospaced")
        )
    )
}
