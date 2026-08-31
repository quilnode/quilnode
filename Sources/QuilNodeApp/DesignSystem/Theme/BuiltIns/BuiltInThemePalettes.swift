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
        typography: .init(scale: 1, displayDesign: .default, dataDesign: .monospaced, heroDesign: .monospaced),
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

}
