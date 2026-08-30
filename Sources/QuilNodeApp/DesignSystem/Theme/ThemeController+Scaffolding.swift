import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ThemeController {
    func prepareThemesDirectory(fileManager: FileManager) {
        do {
            try fileManager.createDirectory(at: themesDirectory, withIntermediateDirectories: true)
            try writeDocumentationIfNeeded(fileManager: fileManager)
        } catch {
            loadIssues = ["Could not prepare the custom themes folder: \(error.localizedDescription)"]
        }
    }

    private func writeDocumentationIfNeeded(fileManager: FileManager) throws {
        let readmeURL = themesDirectory.appendingPathComponent("README-v5.md")
        if !fileManager.fileExists(atPath: readmeURL.path) {
            try Self.themeReadme.write(to: readmeURL, atomically: true, encoding: .utf8)
        }

        let example = themesDirectory.appendingPathComponent("Example-v5.quiltheme.disabled", isDirectory: true)
        guard !fileManager.fileExists(atPath: example.path) else { return }
        try fileManager.createDirectory(at: example, withIntermediateDirectories: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let metadata = QuilThemePackMetadata(
            id: "custom.example", name: "Example Theme", author: "Your Name", version: "1.0.0",
            summary: "A safe, local theme pack.", tags: ["custom"]
        )
        let palette = QuilThemePaletteDocument(
            accent: "#55D6FF", selection: "#2D3748", muted: "#536173",
            background: "#101216", darkBackground: "#171A20", lighterBackground: "#232936",
            foreground: "#F4F7FA", darkForeground: "#8491A3", red: "#FF6B75", yellow: "#F7C66B",
            orange: "#F09A63", green: "#75D99C", cyan: "#55D6FF", blue: "#7AA7FF", magenta: "#B68CFF"
        )
        let style = QuilThemeStyleDocument(
            spacing: .init(scale: 1, panelPadding: 18, panelGap: 16),
            corners: .init(control: 18, hero: 26, navigation: 10),
            controls: .init(
                navigationSelectionStyle: "capsule", selectionFillAlpha: 0.20, ringStyle: "gradient", ringThickness: 9),
            surfaces: .init(
                treatment: "tinted", borderStyle: "solid", surfaceOpacity: 0.75, elevatedOpacity: 0.92,
                borderOpacity: 0.28),
            effects: .init(
                backdrop: "spotlight", decoration: "dots", decorationOpacity: 0.025, shadow: "soft",
                shadowOpacity: 0.14, accentTreatment: "gradient", scene: "orbital", sceneOpacity: 0.55),
            composition: .init(
                pageHeader: "native", sidebarBrand: "tile", hero: "orbital", metricStrip: "ruled", panel: "card",
                badge: "label", dataLabels: "human")
        )
        let variants = QuilThemeVariantsDocument(
            light: .init(
                colors: .init(
                    background: "#F7FAFC", darkBackground: "#EAF0F5", lighterBackground: "#FFFFFF",
                    foreground: "#102030", darkForeground: "#5B6B7A")),
            dark: .init(colors: .init())
        )
        try encoder.encode(metadata).write(to: example.appendingPathComponent("theme.json"), options: .atomic)
        try encoder.encode(palette).write(to: example.appendingPathComponent("colors.json"), options: .atomic)
        try encoder.encode(style).write(to: example.appendingPathComponent("style.json"), options: .atomic)
        try encoder.encode(variants).write(to: example.appendingPathComponent("variants.json"), options: .atomic)
    }

    private static let themeReadme = """
        # QuilNode theme families (schema 5)

        Duplicate `Example-v5.quiltheme.disabled`, rename it to end in `.quiltheme`, and edit:

        - `theme.json`: identity, inheritance, appearance, author, summary, and tags
        - `colors.json`: canonical semantic palette
        - `style.json`: spacing, corners, surfaces, navigation, rings, typography, effects, and component recipes
        - `variants.json`: optional light and dark palette/style overrides for the family
        - `preview.png`: optional artwork for future galleries

        QuilNode detects valid changes automatically. Packs are deliberately data-only: scripts,
        executable hooks, and symbolic links are never loaded. Schema 2, 3, and 4 directory packs and
        legacy `.quiltheme.json` files remain supported. Schema 5 adds the bounded orbital scene and hero recipe;
        older packs inherit their base theme's scene without requiring migration.
        """
}
