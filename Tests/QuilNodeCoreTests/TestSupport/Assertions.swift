import XCTest

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(condition(), message, file: file, line: line)
}
