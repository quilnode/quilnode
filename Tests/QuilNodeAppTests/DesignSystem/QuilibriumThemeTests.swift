import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp

final class QuilibriumThemeTests: XCTestCase {
    func testAppearancesShareLayoutButNotTheirPalette() {
        let dark = QuilTheme.classic
        let light = QuilTheme.classicLight
        XCTAssertEqual(dark.familyID, light.familyID)
        XCTAssertEqual(dark.metrics.sidebarExpandedWidth, light.metrics.sidebarExpandedWidth)
        XCTAssertEqual(dark.metrics.navigationRowHeight, light.metrics.navigationRowHeight)
        XCTAssertEqual(dark.metrics.controlCornerRadius, light.metrics.controlCornerRadius)
        XCTAssertEqual(dark.typography.resolvedHeroDesign, .default)
        XCTAssertEqual(light.typography.resolvedHeroDesign, .default)
        XCTAssertNotEqual(dark.colors.canvas, light.colors.canvas)
        XCTAssertEqual(dark.components.backdropStyle, .gradient)
        XCTAssertEqual(light.components.backdropStyle, .gradient)
    }

    @MainActor
    func testDataAndBodyTextContrastInBothAppearances() throws {
        for theme in [QuilTheme.classic, .classicLight] {
            let textColors = [
                theme.colors.primaryText, theme.colors.secondaryText, theme.colors.accent, theme.colors.accentSecondary,
                theme.colors.success, theme.colors.warning, theme.colors.danger, theme.colors.info,
                theme.colors.frame, theme.colors.wallet, theme.colors.privacy,
            ]
            for foreground in textColors {
                for background in [theme.colors.canvas, theme.colors.surface, theme.colors.surfaceElevated] {
                    XCTAssertGreaterThanOrEqual(try contrast(foreground, background), 4.5, theme.id)
                }
            }
        }
    }

    func testUnrelatedPresetsDoNotInheritBrandAtmosphere() {
        XCTAssertEqual(QuilTheme.builtInDefaults.components.backdropStyle, .solid)
        XCTAssertEqual(QuilTheme.quilNode.components.backdropStyle, .solid)
        XCTAssertEqual(QuilTheme.quilNodeLight.components.backdropStyle, .solid)
        XCTAssertEqual(QuilTheme.graphite.components.backdropStyle, .solid)
        XCTAssertEqual(QuilTheme.builtIns.count, 22)
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
