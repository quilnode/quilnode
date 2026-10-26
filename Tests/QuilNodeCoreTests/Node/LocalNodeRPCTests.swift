import Foundation
import XCTest

@testable import QuilNodeCore

final class LocalNodeRPCTests: XCTestCase {
    private let headers = "HTTP/2 200\r\ncontent-type: application/grpc\r\n\r\ngrpc-status: 0\r\n"

    func testDecodesBoundedPublicMetricsAndRejectsFailedOrMalformedFrames() throws {
        let text = Data("libp2p_connected_peers 81\n".utf8)
        let payload = Data([0x0a, UInt8(text.count)]) + text
        let frame = Data([0, 0, 0, 0, UInt8(payload.count)]) + payload
        XCTAssertEqual(LocalNodeRPC.decode(frame, headers: headers)?[1]?.bytes, text)
        XCTAssertNil(
            LocalNodeRPC.decode(frame, headers: headers.replacingOccurrences(of: "status: 0", with: "status: 13")))
        XCTAssertNil(LocalNodeRPC.decode(frame, headers: headers.replacingOccurrences(of: "200", with: "302")))
        for invalid in [
            Data(), frame.dropLast(), Data([1]) + frame.dropFirst(), frame + Data([0]),
            Data([0, 0, 0, 0, 2, 0x0a, 0x7f]), Data([0, 0, 0, 0, 1, 0]),
        ] {
            XCTAssertNil(LocalNodeRPC.decode(Data(invalid), headers: headers))
        }
    }

    func testNodeInfoUsesPublicRPCFieldsWithoutOpeningAKeyFile() throws {
        let info = try XCTUnwrap(
            LocalNodeRPC.nodeInfo([
                1: .bytes(Data("Qm11111111111111111111111111111111111111111111".utf8)),
                3: .bytes(Data([2, 1, 0])), 7: .bytes(Data([25])),
                5: .integer(8), 8: .integer(935_572), 9: .integer(935_570),
            ]))
        XCTAssertEqual(info.version, "2.1.0.25")
        XCTAssertEqual(info.runningWorkers, 8)
        XCTAssertEqual(info.frame, 935_572)
        XCTAssertNil(info.legacyPeerID)
        XCTAssertNil(info.proverAddress)
    }
}
