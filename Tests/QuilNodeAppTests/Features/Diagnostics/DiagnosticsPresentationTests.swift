import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class DiagnosticsPresentationTests: XCTestCase {
    func testFindingsAreSeparatedFromHealthyChecksAndPrioritized() {
        let report = NodeDiagnosticReport(
            generatedAt: Date(),
            checks: [
                check("pass", state: .passed, category: .runtime),
                check("wait", state: .waiting, category: .progress),
                check("review", state: .advisory, category: .network),
                check("action", state: .failed, category: .tooling),
            ]
        )

        let presentation = DiagnosticsPresentation.make(report: report)

        XCTAssertEqual(presentation.findings.map(\.id), ["action", "review", "wait"])
        XCTAssertEqual(presentation.passedCount, 1)
        XCTAssertEqual(presentation.waitingCount, 1)
        XCTAssertEqual(presentation.reviewCount, 1)
        XCTAssertEqual(presentation.failedCount, 1)
    }

    func testCategoryMatrixRetainsEveryCheck() {
        let report = NodeDiagnosticReport(
            generatedAt: Date(),
            checks: [
                check("runtime-pass", state: .passed, category: .runtime),
                check("runtime-review", state: .advisory, category: .runtime),
                check("chain", state: .passed, category: .progress),
            ]
        )

        let categories = DiagnosticsPresentation.make(report: report).categories

        XCTAssertEqual(categories.flatMap(\.checks).count, 3)
        XCTAssertEqual(categories.first { $0.category == .runtime }?.reviewCount, 1)
        XCTAssertEqual(categories.first { $0.category == .progress }?.passedCount, 1)
    }

    private func check(
        _ id: String,
        state: NodeDiagnosticState,
        category: NodeDiagnosticCategory
    ) -> NodeDiagnosticCheck {
        NodeDiagnosticCheck(
            id: id,
            category: category,
            state: state,
            title: id,
            summary: "summary",
            evidence: "evidence"
        )
    }
}
