import Foundation
import QuilNodeCore

@main
struct QuilNodeProbe {
    static func main() async {
        if CommandLine.arguments.contains("--service-status") {
            let result = PrivilegedServiceClient.request(.status, timeout: 5)
            print("exit=\(result.exitCode) \(result.output)")
            return
        }
        if CommandLine.arguments.contains("--service-node-info") {
            let status = PrivilegedServiceClient.request(.nodeInfo, timeout: 30)
            print("request_exit=\(status.exitCode) \(status.output)")
            if let info = PrivilegedServiceClient.readNodeInfo(timeout: 30) {
                print("version=\(info.version ?? "—")")
                print("peer=\(info.peerID ?? "—")")
                print("seniority_identity=\(info.legacyPeerID ?? "—")")
                print("prover=\(info.proverAddress ?? "—")")
            }
            return
        }
        if CommandLine.arguments.contains("--service-metrics") {
            if let metrics = PrivilegedServiceClient.readMetrics(timeout: 15) {
                print(metrics)
            } else {
                fputs("Unable to read local node metrics through the service.\n", stderr)
                exit(1)
            }
            return
        }
        if CommandLine.arguments.contains("--service-restart") {
            let result = PrivilegedServiceClient.request(.restart, timeout: 30)
            print("exit=\(result.exitCode) \(result.output)")
            return
        }
        let result = await LocalNodeCollector().collect(refreshNodeInfo: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(result.snapshot)
            print(String(decoding: data, as: UTF8.self))
        } catch {
            fputs("Unable to encode local node status: \(error)\n", stderr)
            exit(1)
        }
    }
}
