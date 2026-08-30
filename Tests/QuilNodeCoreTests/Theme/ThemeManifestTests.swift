import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class ThemeManifestTests: XCTestCase {
    func testThemeManifestValidationAndRoundTrips() {
        let themeManifest = QuilThemeManifest(
            id: "custom.night-owl",
            name: "Night Owl",
            author: "Local operator",
            version: "1.0.0",
            colors: .init(accent: "#55D6FF", canvas: "#101216FF"),
            metrics: .init(sidebarCollapsedWidth: 68, controlCornerRadius: 18),
            typography: .init(scale: 1.05, displayDesign: "rounded")
        )
        expect(themeManifest.validationIssues().isEmpty, "valid custom theme manifest")
        if let data = try? JSONEncoder().encode(themeManifest),
            let decoded = try? JSONDecoder().decode(QuilThemeManifest.self, from: data)
        {
            expect(decoded == themeManifest, "theme manifest Codable round trip")
        } else {
            XCTFail("theme manifest Codable round trip")
        }
        var invalidTheme = themeManifest
        invalidTheme.id = "Not Valid"
        invalidTheme.colors.accent = "purple"
        expect(invalidTheme.validationIssues().count == 2, "invalid theme validation")
        expect(QuilThemeManifest.currentSchemaVersion == 1, "theme schema version")

        let themePackMetadata = QuilThemePackMetadata(
            id: "custom.deep-ocean",
            name: "Deep Ocean",
            author: "Local operator",
            version: "2.0.0",
            base: "omarchy.tokyo-night",
            appearance: .dark,
            summary: "A full theme pack",
            tags: ["dark", "compact"]
        )
        let themePackPalette = QuilThemePaletteDocument(
            accent: "#55D6FF", selection: "#283445", muted: "#526173",
            background: "#101216", darkBackground: "#0B0D10", lighterBackground: "#1A202A",
            foreground: "#F4F7FA", darkForeground: "#8491A3", red: "#FF6677", yellow: "#F6C85F",
            orange: "#F29D62", green: "#76DBA0", cyan: "#55D6FF", blue: "#7AA7FF", magenta: "#B68CFF"
        )
        let themePackStyle = QuilThemeStyleDocument(
            spacing: .init(scale: 0.95, panelPadding: 16, panelGap: 12),
            corners: .init(control: 12, hero: 18, navigation: 7),
            controls: .init(
                navigationSelectionStyle: "capsule", selectionFillAlpha: 0.2, ringStyle: "solid", ringThickness: 8),
            surfaces: .init(
                treatment: "tinted", borderStyle: "dashed", surfaceOpacity: 0.8, elevatedOpacity: 0.95,
                borderOpacity: 0.3),
            typography: .init(scale: 1, displayDesign: "rounded", dataDesign: "monospaced"),
            effects: .init(
                backdrop: "spotlight", decoration: "grid", decorationOpacity: 0.04, shadow: "soft", shadowOpacity: 0.12),
            composition: .init(
                pageHeader: "output", sidebarBrand: "wordmark", hero: "terminal", metricStrip: "cells",
                panel: "terminal", badge: "label", dataLabels: "terminal")
        )
        let themeVariants = QuilThemeVariantsDocument(
            light: .init(colors: .init(background: "#FFFFFF", foreground: "#102030")),
            dark: .init(colors: .init(background: "#081018", foreground: "#F4F8FA"))
        )
        let themePack = QuilThemePack(
            metadata: themePackMetadata, colors: themePackPalette, style: themePackStyle, variants: themeVariants)
        expect(themePack.validationIssues().isEmpty, "valid schema 4 theme family")
        expect(QuilThemePackMetadata.currentSchemaVersion == 4, "theme pack schema version")
        var legacyThemePackMetadata = themePackMetadata
        legacyThemePackMetadata.schemaVersion = 2
        expect(legacyThemePackMetadata.validationIssues().isEmpty, "schema 2 theme pack compatibility")
        legacyThemePackMetadata.schemaVersion = 3
        expect(legacyThemePackMetadata.validationIssues().isEmpty, "schema 3 theme pack compatibility")
        if let data = try? JSONEncoder().encode(themePackMetadata),
            let decoded = try? JSONDecoder().decode(QuilThemePackMetadata.self, from: data)
        {
            expect(decoded == themePackMetadata, "theme pack metadata round trip")
        } else {
            XCTFail("theme pack metadata round trip")
        }
        if let data = try? JSONEncoder().encode(themePackPalette),
            let decoded = try? JSONDecoder().decode(QuilThemePaletteDocument.self, from: data)
        {
            expect(decoded == themePackPalette, "theme palette round trip")
        } else {
            XCTFail("theme palette round trip")
        }
        if let data = try? JSONEncoder().encode(themePackStyle),
            let decoded = try? JSONDecoder().decode(QuilThemeStyleDocument.self, from: data)
        {
            expect(decoded == themePackStyle, "theme style round trip")
            expect(decoded.surfaces.borderStyle == "dashed", "theme surface border style round trip")
            expect(decoded.composition.pageHeader == "output", "theme composition recipe round trip")
        } else {
            XCTFail("theme style round trip")
        }
        if let data = try? JSONEncoder().encode(themeVariants),
            let decoded = try? JSONDecoder().decode(QuilThemeVariantsDocument.self, from: data)
        {
            expect(decoded == themeVariants, "theme light/dark variants round trip")
        } else {
            XCTFail("theme variants round trip")
        }
        var invalidThemePackStyle = themePackStyle
        invalidThemePackStyle.controls.navigationSelectionStyle = "glowing-orb"
        invalidThemePackStyle.spacing.sidebarCollapsedWidth = 20
        invalidThemePackStyle.surfaces.borderStyle = "scribbled"
        invalidThemePackStyle.composition.hero = "floating-cube"
        expect(invalidThemePackStyle.validationIssues().count == 4, "invalid component theme tokens")
        let partialStyleJSON =
            #"{"controls":{"ringStyle":"solid"},"effects":{"decoration":"scanlines"},"composition":{"panel":"ruled"}}"#
            .data(using: .utf8)!
        if let partialStyle = try? JSONDecoder().decode(QuilThemeStyleDocument.self, from: partialStyleJSON) {
            expect(partialStyle.controls.ringStyle == "solid", "partial theme style decoding")
            expect(partialStyle.effects.decoration == "scanlines", "partial theme effect decoding")
            expect(partialStyle.composition.panel == "ruled", "partial theme composition decoding")
            expect(partialStyle.spacing.scale == nil, "partial theme style defaults")
        } else {
            XCTFail("partial theme style decoding")
        }

    }
}
