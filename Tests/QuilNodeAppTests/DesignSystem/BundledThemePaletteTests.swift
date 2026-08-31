import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp

final class BundledThemePaletteTests: XCTestCase {
    private var secondaryThemes: [QuilTheme] {
        QuilTheme.builtIns.filter { !["quilnode.default", "quil.classic"].contains($0.familyID) }
    }

    @MainActor
    func testTextAndTelemetryRemainReadableOnEachSurface() throws {
        for theme in secondaryThemes {
            let foregrounds: [(String, Color)] = [
                ("primary", theme.colors.primaryText), ("secondary", theme.colors.secondaryText),
                ("accent", theme.colors.accent), ("secondary accent", theme.colors.accentSecondary),
                ("success", theme.colors.success), ("warning", theme.colors.warning),
                ("danger", theme.colors.danger), ("info", theme.colors.info),
                ("frame", theme.colors.frame), ("wallet", theme.colors.wallet), ("privacy", theme.colors.privacy),
            ]
            let backgrounds: [(String, Color)] = [
                ("canvas", theme.colors.canvas), ("sidebar", theme.colors.sidebar),
                ("surface", theme.colors.surface), ("elevated", theme.colors.surfaceElevated),
            ]
            for (role, foreground) in foregrounds {
                for (surface, background) in backgrounds {
                    XCTAssertGreaterThanOrEqual(
                        try contrast(foreground, background), 4.5, "\(theme.id): \(role) on \(surface)")
                }
            }
        }
    }

    func testAppearanceChangesPreserveFamilyGeometry() throws {
        for (family, variants) in Dictionary(grouping: secondaryThemes, by: \.familyID) {
            let dark = try XCTUnwrap(variants.first { $0.appearance == .dark }, family)
            let light = try XCTUnwrap(variants.first { $0.appearance == .light }, family)
            XCTAssertEqual(dark.name, light.name, family)
            XCTAssertEqual(dark.metrics.sidebarExpandedWidth, light.metrics.sidebarExpandedWidth, family)
            XCTAssertEqual(dark.metrics.navigationRowHeight, light.metrics.navigationRowHeight, family)
            XCTAssertEqual(dark.metrics.controlCornerRadius, light.metrics.controlCornerRadius, family)
            XCTAssertEqual(dark.typography.resolvedHeroDesign, light.typography.resolvedHeroDesign, family)
            XCTAssertEqual(dark.components.navigationSelection, light.components.navigationSelection, family)
            XCTAssertEqual(dark.components.backdropStyle, light.components.backdropStyle, family)
            XCTAssertNotEqual(dark.colors.canvas, light.colors.canvas, family)
        }
    }

    func testSuccessWarningAndDangerRemainDistinct() {
        for theme in secondaryThemes {
            XCTAssertNotEqual(theme.colors.success, theme.colors.warning, theme.id)
            XCTAssertNotEqual(theme.colors.warning, theme.colors.danger, theme.id)
            XCTAssertNotEqual(theme.colors.success, theme.colors.danger, theme.id)
        }
    }

    func testSecondaryThemesUseStaticEffectsAndLegibleTypeScale() {
        for theme in secondaryThemes {
            XCTAssertEqual(theme.components.sceneStyle, .none, theme.id)
            XCTAssertEqual(theme.typography.scale, 1, theme.id)
            XCTAssertGreaterThanOrEqual(theme.metrics.navigationRowHeight, 40, theme.id)
        }
    }

    @MainActor
    private func contrast(_ foreground: Color, _ background: Color) throws -> Double {
        func luminance(_ color: Color) throws -> Double {
            let rgb = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
            func linear(_ value: CGFloat) -> Double {
                let channel = Double(value)
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent)
                + 0.0722 * linear(rgb.blueComponent)
        }
        let first = try luminance(foreground)
        let second = try luminance(background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
