import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension PrivilegedServiceClient {
    public static func readNodeSockets(timeout: TimeInterval = 5) -> ProcessSocketInspection? {
        let result = response(.nodeSockets, timeout: timeout)
        guard result.exitCode == 0, let response = result.response,
            let sockets = response.nodeSockets, sockets.processID == response.nodePID,
            sockets.observedAt.timeIntervalSinceNow >= -15,
            sockets.observedAt.timeIntervalSinceNow <= 5
        else { return nil }
        return sockets
    }

    public static func readNodeInfo(timeout: TimeInterval = 75) -> NodeInfo? {
        let result = response(.nodeInfo, timeout: timeout)
        guard result.exitCode == 0, let response = result.response else { return nil }
        var info = NodeInfoParser.parse(response.nodeInfoOutput ?? "")
        let peerInfo = NodeInfoParser.parse(response.peerInfoOutput ?? "")
        info.peerID = info.peerID ?? peerInfo.peerID
        info.legacyPeerID = peerInfo.legacyPeerID
        return info.version == nil && info.peerID == nil && info.proverAddress == nil ? nil : info
    }

    public static func readMetrics(timeout: TimeInterval = 10) -> String? {
        let result = response(.metrics, timeout: timeout)
        guard result.exitCode == 0 else { return nil }
        return result.response?.metricsOutput
    }

    public static func readBalance(timeout: TimeInterval = 195) -> (balance: QuilBalance?, error: String?) {
        let result = response(.balance, timeout: timeout)
        guard result.exitCode == 0, let response = result.response else {
            return (nil, result.error)
        }
        return parseBalanceResponse(response)
    }

    static func parseBalanceResponse(_ response: PrivilegedServiceResponse) -> (balance: QuilBalance?, error: String?) {
        let balance = QuilBalanceParser.parse(response.balanceOutput ?? "")
        if response.balanceTimedOut == true {
            return (
                balance,
                "Wallet lookup timed out. Only completed components are shown; unavailable amounts are unknown."
            )
        }
        if let code = response.balanceExitCode, code != 0 {
            return (balance, "The local wallet could not read every component. Unavailable amounts are unknown.")
        }
        guard let balance else {
            return (nil, "The local wallet returned an unreadable balance response. Check the managed qclient update.")
        }
        return (
            balance, balance.isComplete ? nil : "Some wallet components are unavailable or not reported by this client."
        )
    }

    public static func readProverTelemetry(
        timeout: TimeInterval = 75
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
        timeout: TimeInterval = 20
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
