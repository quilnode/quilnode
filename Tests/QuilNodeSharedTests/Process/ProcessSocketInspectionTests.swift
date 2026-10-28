import Darwin
import XCTest

@testable import QuilNodeShared

final class ProcessSocketInspectionTests: XCTestCase {
    func testInspectsOnlyOwnedTCPListenersAndUDPBindingsWithoutNetstat() throws {
        let tcp = try boundSocket(type: SOCK_STREAM)
        defer { close(tcp.fd) }
        XCTAssertEqual(listen(tcp.fd, 1), 0)
        let udp = try boundSocket(type: SOCK_DGRAM)
        defer { close(udp.fd) }
        let unlistening = try boundSocket(type: SOCK_STREAM)
        defer { close(unlistening.fd) }

        let result = try XCTUnwrap(ProcessSocketInspector.inspect(processID: getpid()))
        XCTAssertEqual(result.processID, getpid())
        XCTAssertTrue(result.tcpListeners.contains(tcp.port))
        XCTAssertTrue(result.udpBindings.contains(udp.port))
        XCTAssertFalse(result.tcpListeners.contains(unlistening.port), "A bound TCP socket is not yet a listener.")
        XCTAssertLessThan(abs(result.observedAt.timeIntervalSinceNow), 5)
    }

    func testInvalidOrDisappearedProcessIsUnavailableInsteadOfMissingListeners() {
        XCTAssertNil(ProcessSocketInspector.inspect(processID: 0))
        XCTAssertNil(ProcessSocketInspector.inspect(processID: -1))
        XCTAssertNil(ProcessSocketInspector.inspect(processID: Int32.max))
    }

    func testWirePayloadIsOptionalForOlderServicesAndExcludesPeerAddresses() throws {
        let legacy = Data(#"{"protocolVersion":1,"success":true,"message":"ready"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(PrivilegedServiceResponse.self, from: legacy).nodeSockets)
        let payload = ProcessSocketInspection(processID: 42, tcpListeners: [8336, 8340])
        let response = PrivilegedServiceResponse(success: true, message: "ready", nodePID: 42, nodeSockets: payload)
        let data = try JSONEncoder().encode(response)
        XCTAssertEqual(try JSONDecoder().decode(PrivilegedServiceResponse.self, from: data).nodeSockets, payload)
    }

    private func boundSocket(type: Int32) throws -> (fd: Int32, port: UInt16) {
        let fd = socket(AF_INET, type, 0)
        guard fd >= 0 else { throw POSIXError(.ENFILE) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = in_addr_t(INADDR_LOOPBACK).bigEndian
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            close(fd)
            throw POSIXError(.EADDRINUSE)
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        guard named == 0 else {
            close(fd)
            throw POSIXError(.EBADF)
        }
        return (fd, UInt16(bigEndian: address.sin_port))
    }
}
