import XCTest

@testable import QuilNodeApp

final class ThemeLibraryPresentationTests: XCTestCase {
    func testEmptySearchKeepsEveryThemeInCatalogOrder() {
        let themes = QuilTheme.builtIns.filter { $0.appearance == .light }

        XCTAssertEqual(
            ThemeLibraryPresentation.filteredThemes(themes, query: "  ").map(\.id),
            themes.map(\.id)
        )
    }

    func testSearchMatchesNameSummaryAuthorAndTagsCaseInsensitively() {
        let themes = QuilTheme.builtIns.filter { $0.appearance == .light }

        XCTAssertTrue(
            ThemeLibraryPresentation.filteredThemes(themes, query: "QUILIBRIUM").contains {
                $0.familyID == QuilTheme.classic.familyID
            }
        )
        XCTAssertFalse(ThemeLibraryPresentation.filteredThemes(themes, query: "OMARCHY").isEmpty)
        XCTAssertTrue(
            ThemeLibraryPresentation.filteredThemes(themes, query: "operations").contains {
                $0.familyID == QuilTheme.quilNode.familyID
            }
        )
    }

    func testVariantLabelsDescribeAvailableAppearanceModes() {
        XCTAssertEqual(ThemeLibraryPresentation.variantLabel(supportsLight: true, supportsDark: true), "L · D")
        XCTAssertEqual(ThemeLibraryPresentation.variantLabel(supportsLight: true, supportsDark: false), "LIGHT")
        XCTAssertEqual(ThemeLibraryPresentation.variantLabel(supportsLight: false, supportsDark: true), "DARK")
        XCTAssertEqual(ThemeLibraryPresentation.variantLabel(supportsLight: false, supportsDark: false), "SYSTEM")
    }

    func testProvenanceSeparatesBundledAndCustomThemes() {
        XCTAssertTrue(ThemeLibraryPresentation.provenance(for: .quilNode).hasPrefix("Built in"))
    }
}
