import Darwin
import Foundation
import XCTest

@testable import QuilNodeShared

final class LiveProcessOutputTests: XCTestCase {
    func testSmallOutputIsVisibleBeforeTheWriterCloses() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let descriptor = open(url.path, O_RDWR | O_CREAT | O_EXCL, 0o600)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        guard descriptor >= 0 else { return }
        defer {
            close(descriptor)
            try? FileManager.default.removeItem(at: url)
        }
        let pump = BoundedProcessOutputPump(destinationDescriptor: descriptor, maximumBytes: 512)
        pump.start()
        defer {
            try? pump.pipe.fileHandleForWriting.close()
            pump.waitUntilDrained()
        }
        try pump.pipe.fileHandleForWriting.write(contentsOf: Data("Compiling wallet\n".utf8))
        let deadline = Date().addingTimeInterval(2)
        var metadata = stat()
        while Date() < deadline {
            _ = fstat(descriptor, &metadata)
            if metadata.st_size > 0 { break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        XCTAssertEqual(metadata.st_size, 17, "Live logs must not wait for 64 KB or EOF.")
        XCTAssertFalse(pump.exceededLimit)
        XCTAssertFalse(pump.failedWriting)
    }
}
