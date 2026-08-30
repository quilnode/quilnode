import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension PrivilegedServiceClient {
    public static func readNodeInfo(timeout: TimeInterval = 30) -> NodeInfo? {
        let result = response(.nodeInfo, timeout: timeout)
        guard result.exitCode == 0, let response = result.response else { return nil }
        var info = NodeInfoParser.parse(response.nodeInfoOutput ?? "")
        let peerInfo = NodeInfoParser.parse(response.peerInfoOutput ?? "")
        info.legacyPeerID = peerInfo.legacyPeerID
        return info.version == nil && info.peerID == nil && info.proverAddress == nil ? nil : info
    }

    public static func readMetrics(timeout: TimeInterval = 10) -> String? {
        let result = response(.metrics, timeout: timeout)
        guard result.exitCode == 0 else { return nil }
        return result.response?.metricsOutput
    }

    public static func readBalance(timeout: TimeInterval = 45) -> (balance: QuilBalance?, error: String?) {
        let result = response(.balance, timeout: timeout)
        guard result.exitCode == 0, let response = result.response else {
            return (nil, result.error)
        }
        guard let balance = QuilBalanceParser.parse(response.balanceOutput ?? "") else {
            return (nil, "The local wallet returned an unreadable balance response.")
        }
        return (balance, nil)
    }

    public static func readProverTelemetry(
        timeout: TimeInterval = 35
    ) -> (telemetry: LocalProverTelemetry?, error: String?) {
        let result = response(.proverTelemetry, timeout: timeout)
        guard result.exitCode == 0,
            let output = result.response?.qclientOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(QClientProverTelemetryPayload.self, from: data),
            let telemetry = LocalProverTelemetryParser.parse(payload)
        else {
            return (nil, "The secure service returned unreadable local prover telemetry.")
        }
        return (telemetry, nil)
    }

    public static func readQClientStatus(
        timeout: TimeInterval = 8
    ) -> (status: ManagedQClientStatus?, error: String?) {
        let result = response(.qclientStatus, timeout: timeout)
        guard result.exitCode == 0,
            let output = result.response?.qclientOutput,
            let data = output.data(using: .utf8)
        else { return (nil, result.response?.message ?? result.error) }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return (try decoder.decode(ManagedQClientStatus.self, from: data), nil)
        } catch {
            return (nil, "The secure service returned unreadable qclient provenance.")
        }
    }
}
