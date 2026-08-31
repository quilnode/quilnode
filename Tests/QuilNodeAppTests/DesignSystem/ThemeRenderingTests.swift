import QuilNodeShared
import SwiftUI
import XCTest

@testable import QuilNodeApp

final class ThemeRenderingTests: XCTestCase {
    func testHeroFallsBackToDisplayDesign() {
        let typography = QuilTheme.Typography(scale: 1, displayDesign: .serif, dataDesign: .monospaced)
        XCTAssertEqual(typography.resolvedHeroDesign, .serif)
    }

    func testExplicitHeroDesignDoesNotChangeBodyOrDataTypography() {
        let typography = QuilTheme.quilNode.typography.applying(
            QuilThemeStyleDocument(typography: .init(heroDesign: "rounded"))
        )
        XCTAssertEqual(typography.resolvedHeroDesign, .rounded)
        XCTAssertEqual(typography.displayDesign, .default)
        XCTAssertEqual(typography.dataDesign, .monospaced)
    }

    func testExistingCustomDisplayOverrideAlsoAppliesToHero() {
        let typography = QuilTheme.quilNode.typography.applying(
            QuilThemeStyleDocument(typography: .init(displayDesign: "serif"))
        )
        XCTAssertEqual(typography.resolvedHeroDesign, .serif)
        XCTAssertEqual(typography.dataDesign, .monospaced)
    }

    func testDefaultProductKeepsItsTerminalHeadingInBothAppearances() {
        for theme in [QuilTheme.quilNode, .quilNodeLight] {
            XCTAssertEqual(theme.typography.resolvedHeroDesign, .monospaced)
            XCTAssertEqual(theme.components.backdropStyle, .solid)
        }
    }

    func testHeroDesignIsOptionalBoundedDataAndRoundTrips() throws {
        let minimal = try JSONDecoder().decode(QuilThemeStyleDocument.self, from: Data("{}".utf8))
        XCTAssertNil(minimal.typography.heroDesign)
        let style = QuilThemeStyleDocument(typography: .init(heroDesign: "rounded"))
        XCTAssertTrue(style.validationIssues().isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(QuilThemeStyleDocument.self, from: JSONEncoder().encode(style)), style)
        XCTAssertFalse(QuilThemeStyleDocument(typography: .init(heroDesign: "remote-font")).validationIssues().isEmpty)
    }
}
