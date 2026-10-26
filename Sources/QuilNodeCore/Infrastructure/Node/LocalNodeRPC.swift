import Foundation
import QuilNodeShared

/// Two fixed public reads from the managed node's loopback gRPC listener.
/// Avoids starting another full node (and its ceremony setup) for every poll.
enum LocalNodeRPC {
    enum Method: String { case nodeInfo = "GetNodeInfo", metrics = "GetMetrics" }
    static let maximumBytes = 1_048_576

    static func read(_ method: Method) -> [Int: Field]? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("quilnode-rpc-\(UUID())")
        do {
            try PrivateLocalFileSystem.createExclusiveDirectory(at: directory)
            defer { try? FileManager.default.removeItem(at: directory) }
            let request = directory.appendingPathComponent("request")
            let response = directory.appendingPathComponent("response")
            let headers = directory.appendingPathComponent("headers")
            try PrivateLocalFileSystem.write(Data(repeating: 0, count: 5), atomicallyTo: request)
            let result = BoundedCommandRunner.run(
                executable: "/usr/bin/curl",
                arguments: [
                    "--disable", "--silent", "--show-error", "--noproxy", "*", "--proto", "=http",
                    "--http2-prior-knowledge", "--connect-timeout", "1", "--max-time", "4",
                    "--max-filesize", String(maximumBytes), "--header", "Content-Type: application/grpc",
                    "--header", "TE: trailers", "--data-binary", "@\(request.path)",
                    "--output", response.path, "--dump-header", headers.path,
                    "http://127.0.0.1:8337/quilibrium.node.node.pb.NodeService/\(method.rawValue)",
                ], timeout: 5, maximumOutputBytes: 4_096
            )
            guard result.exitCode == 0, !result.timedOut,
                let headerData = try? BoundedLocalData.read(from: headers, maximumBytes: 16_384),
                let body = try? BoundedLocalData.read(from: response, maximumBytes: maximumBytes)
            else { return nil }
            return decode(body, headers: String(decoding: headerData, as: UTF8.self))
        } catch { return nil }
    }

    enum Field: Equatable {
        case integer(UInt64), bytes(Data)
        var integer: UInt64? { if case .integer(let value) = self { value } else { nil } }
        var bytes: Data? { if case .bytes(let value) = self { value } else { nil } }
    }

    static func decode(_ frame: Data, headers: String) -> [Int: Field]? {
        let lines = headers.lowercased().split(whereSeparator: \.isNewline).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard lines.contains("http/2 200"),
            lines.contains(where: { $0.hasPrefix("content-type: application/grpc") }),
            lines.last(where: { $0.hasPrefix("grpc-status:") }) == "grpc-status: 0",
            frame.count >= 5, frame.count <= maximumBytes, frame.first == 0
        else { return nil }
        let length = frame.dropFirst().prefix(4).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard length == frame.count - 5 else { return nil }
        let bytes = [UInt8](frame.dropFirst(5))
        var index = 0
        func varint() -> UInt64? {
            var value: UInt64 = 0
            for shift in stride(from: 0, through: 63, by: 7) {
                guard index < bytes.count else { return nil }
                let byte = bytes[index]
                index += 1
                guard shift < 63 || byte <= 1 else { return nil }
                value |= UInt64(byte & 0x7f) << shift
                if byte & 0x80 == 0 { return value }
            }
            return nil
        }
        var fields: [Int: Field] = [:]
        while index < bytes.count {
            guard let tag = varint(), tag >> 3 > 0, tag >> 3 <= 536_870_911 else { return nil }
            let number = Int(tag >> 3)
            switch tag & 7 {
            case 0:
                guard let value = varint() else { return nil }
                fields[number] = .integer(value)
            case 2:
                guard let count = varint(), count <= bytes.count - index else { return nil }
                fields[number] = .bytes(Data(bytes[index..<(index + Int(count))]))
                index += Int(count)
            case 1, 5:
                let count = tag & 7 == 1 ? 8 : 4
                guard count <= bytes.count - index else { return nil }
                index += count
            default: return nil
            }
        }
        return fields
    }

    static func nodeInfo(_ fields: [Int: Field]) -> NodeInfo? {
        guard let peerData = fields[1]?.bytes, let peer = String(data: peerData, encoding: .utf8),
            peer.count >= 32, peer.count <= 128, peer.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
            let version = fields[3]?.bytes, version.count == 3
        else { return nil }
        let parts = [UInt8](version) + Array((fields[7]?.bytes ?? Data()).prefix(1))
        return NodeInfo(
            peerID: peer, version: parts.map(String.init).joined(separator: "."),
            runningWorkers: Int(clamping: fields[5]?.integer ?? 0),
            frame: max(fields[8]?.integer ?? 0, fields[9]?.integer ?? 0)
        )
    }
}
