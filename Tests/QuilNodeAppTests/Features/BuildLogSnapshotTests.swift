import XCTest

@testable import QuilNodeApp

final class BuildLogSnapshotTests: XCTestCase {
    func testParserCountsCompilerDiagnosticsWithoutInventingState() {
        let snapshot = BuildLogSnapshot.parse(
            """
            Compiling quil-types
            warning: unused import
            error: protoc failed
            Build failed with 1 error
            """,
            observedAt: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(snapshot.warningCount, 1)
        XCTAssertEqual(snapshot.errorCount, 1)
        XCTAssertEqual(snapshot.latestEvent, "Build failed with 1 error")
        XCTAssertEqual(snapshot.visibleLineCount, 4)
    }

    func testParserBoundsLinesAndReportsTrimmedTail() {
        let text = (0..<400).map { "line \($0)" }.joined(separator: "\n")
        let snapshot = BuildLogSnapshot.parse(text)

        XCTAssertEqual(snapshot.visibleLineCount, 320)
        XCTAssertTrue(snapshot.wasTrimmed)
        XCTAssertTrue(snapshot.output.hasPrefix("line 80"))
        XCTAssertEqual(snapshot.latestEvent, "line 399")
    }

    func testByteLimitMarksEvenShortTailAsTrimmed() {
        let snapshot = BuildLogSnapshot.parse("one\ntwo", reachedByteLimit: true)

        XCTAssertTrue(snapshot.wasTrimmed)
        XCTAssertEqual(snapshot.visibleLineCount, 2)
    }

    func testTerminalNewlineDoesNotCreateAPhantomVisibleLine() {
        let snapshot = BuildLogSnapshot.parse("one\ntwo\n")

        XCTAssertEqual(snapshot.visibleLineCount, 2)
        XCTAssertEqual(snapshot.output, "one\ntwo")
        XCTAssertEqual(snapshot.latestEvent, "two")
    }

    func testLongLatestEventIsCompactButRawOutputIsPreserved() {
        let line = String(repeating: "a", count: 140)
        let snapshot = BuildLogSnapshot.parse(line)

        XCTAssertEqual(snapshot.output, line)
        XCTAssertEqual(snapshot.latestEvent.count, 108)
        XCTAssertTrue(snapshot.latestEvent.hasSuffix("…"))
    }

    func testEvidenceEqualityIgnoresObservationTimeButNotOutputChanges() {
        let first = BuildLogSnapshot.parse(
            "Compiling one",
            observedAt: Date(timeIntervalSince1970: 10)
        )
        let repeatedRead = BuildLogSnapshot.parse(
            "Compiling one",
            observedAt: Date(timeIntervalSince1970: 20)
        )
        let changed = BuildLogSnapshot.parse(
            "Compiling two",
            observedAt: Date(timeIntervalSince1970: 20)
        )

        XCTAssertTrue(first.hasSameEvidence(as: repeatedRead))
        XCTAssertFalse(first.hasSameEvidence(as: changed))
    }
}
