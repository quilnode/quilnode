import Foundation
import QuilNodeShared

public struct NetworkLocalInspector: Sendable {
    public init() {}

    public func inspect(
        processID: Int32?,
        portPlan: NetworkPortPlan = .residentialTCP(localWorkerCount: nil)
    ) -> NetworkLocalInspection {
        guard let processID else { return .empty }
        let route = run("/sbin/route", ["-n", "get", "default"], timeout: 2)
        let interface = lineValue("interface", in: route.output)
        let gateway = lineValue("gateway", in: route.output)
        let interfaceDisplayName = interface.flatMap(hardwarePortName)
        let localIP = interface.flatMap {
            let result = run("/usr/sbin/ipconfig", ["getifaddr", $0], timeout: 2)
            return result.exitCode == 0 ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        }

        // macOS can silently redact the system-wide netstat table. Inspect
        // only this process, through its existing authenticated service when
        // the node runs under the isolated account.
        let sockets =
            ProcessSocketInspector.inspect(processID: processID)
            ?? PrivilegedServiceClient.readNodeSockets()
        let current = sockets.flatMap { $0.processID == processID ? $0 : nil }
        let firewall = readFirewallState()
        return NetworkLocalInspection(
            processID: processID,
            listenerInspectionError: current == nil
                ? "macOS did not expose this node's listeners. Inbound node metrics are checked separately." : nil,
            localIPv4: localIP,
            gatewayIPv4: gateway,
            interfaceName: interface,
            interfaceDisplayName: interfaceDisplayName,
            firewallState: firewall,
            tcpListeners: current?.tcpListeners ?? [],
            udpListeners: current?.udpBindings ?? [],
            inspectionSucceeded: current != nil
        )
    }

    private func hardwarePortName(for interface: String) -> String? {
        let result = run("/usr/sbin/networksetup", ["-listallhardwareports"], timeout: 2)
        guard result.exitCode == 0 else { return nil }
        var hardwarePort: String?
        for raw in result.output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("Hardware Port:") {
                hardwarePort = line.dropFirst("Hardware Port:".count).trimmingCharacters(in: .whitespaces)
            } else if line == "Device: \(interface)" {
                return hardwarePort
            }
        }
        return nil
    }

    private func readFirewallState() -> NetworkFirewallState {
        let tool = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        let global = run(tool, ["--getglobalstate"], timeout: 2)
        guard global.exitCode == 0 else { return .unknown }
        if global.output.localizedCaseInsensitiveContains("disabled") { return .disabled }
        let blockAll = run(tool, ["--getblockall"], timeout: 2)
        if blockAll.output.localizedCaseInsensitiveContains("enabled") { return .blockingAll }
        return .enabled
    }

    private func lineValue(_ key: String, in output: String) -> String? {
        output.split(separator: "\n").compactMap { raw -> String? in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("\(key):") else { return nil }
            return line.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
        }.first
    }

    private func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> NetworkCommandResult {
        let result = BoundedCommandRunner.run(
            executable: executable,
            arguments: arguments,
            timeout: timeout,
            maximumOutputBytes: 2 * 1_024 * 1_024
        )
        return NetworkCommandResult(
            output: result.output,
            exitCode: result.exitCode
        )
    }
}

private struct NetworkCommandResult {
    var output: String
    var exitCode: Int32
}
