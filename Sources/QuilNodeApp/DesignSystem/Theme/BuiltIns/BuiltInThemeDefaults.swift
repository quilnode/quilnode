import SwiftUI

extension QuilTheme {
    // Stable inheritance defaults, separate from selectable brand presets.
    // Refining one preset must not silently restyle unrelated theme families.
    static let builtInDefaults = QuilTheme(
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
        typography: .init(scale: 1, displayDesign: .default, dataDesign: .monospaced, heroDesign: .monospaced),
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
}
