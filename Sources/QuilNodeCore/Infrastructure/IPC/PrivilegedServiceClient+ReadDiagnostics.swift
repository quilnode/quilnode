import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension PrivilegedServiceClient {
    /// Explicit local troubleshooting through the authenticated app identity.
    /// Only existing read operations are available; this cannot accept a path,
    /// executable, transaction, or arbitrary privileged action from the CLI.
    public static func localReadDiagnostics(serviceOnly: Bool = false) -> String {
        var report: [String: Any] = [:]
        if !serviceOnly {
            let info = LocalNodeRPC.read(.nodeInfo).flatMap(LocalNodeRPC.nodeInfo)
            let metrics = LocalNodeRPC.read(.metrics)?[1]?.bytes.map { String(decoding: $0, as: UTF8.self) }
            report["telemetry"] = [
                "source": "managed node loopback RPC",
                "nodeInfoAvailable": info != nil,
                "metricsAvailable": metrics != nil,
                "frame": info?.frame as Any? ?? NSNull(),
                "runningWorkers": info?.runningWorkers as Any? ?? NSNull(),
                "version": info?.version as Any? ?? NSNull(),
                "metrics": (metrics ?? "").split(separator: "\n")
                    .filter { $0.contains("libp2p_") }.map(String.init).joined(separator: "\n"),
            ]
        }
        let reads: [(String, PrivilegedServiceAction, TimeInterval)] =
            serviceOnly
            ? [("service", .capabilities, 10)]
            : [
                ("service", .capabilities, 10), ("client", .qclientStatus, 10), ("identity", .nodeInfo, 75),
                ("prover", .proverTelemetry, 35), ("wallet", .balance, 195),
            ]
        for (name, action, timeout) in reads {
            let result = response(action, timeout: timeout)
            report[name] = [
                "exitCode": result.exitCode,
                "serviceBuild": result.response?.serviceBuild as Any? ?? NSNull(),
                "message": result.response?.message ?? result.error,
                "nodeInfo": result.response?.nodeInfoOutput ?? "",
                "peerInfo": result.response?.peerInfoOutput ?? "",
                "metrics": (result.response?.metricsOutput ?? "").split(separator: "\n")
                    .filter { $0.contains("libp2p_") }.map(String.init).joined(separator: "\n"),
                "clientOutput": result.response?.qclientOutput ?? "",
                "balanceOutput": result.response?.balanceOutput ?? "",
                "balanceExitCode": result.response?.balanceExitCode as Any? ?? NSNull(),
                "balanceTimedOut": result.response?.balanceTimedOut as Any? ?? NSNull(),
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        else { return "Unable to encode local read diagnostics.\n" }
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}
