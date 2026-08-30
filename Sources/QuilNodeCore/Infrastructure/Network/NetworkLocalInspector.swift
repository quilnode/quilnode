import Foundation

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

        let tcp = run("/usr/sbin/netstat", ["-anv", "-p", "tcp"], timeout: 3)
        let udp = run("/usr/sbin/netstat", ["-anv", "-p", "udp"], timeout: 3)
        let firewall = readFirewallState()
        return NetworkLocalInspection(
            localIPv4: localIP,
            gatewayIPv4: gateway,
            interfaceName: interface,
            interfaceDisplayName: interfaceDisplayName,
            firewallState: firewall,
            tcpListeners: listenerPorts(in: tcp.output, processID: processID, transport: .tcp),
            udpListeners: listenerPorts(in: udp.output, processID: processID, transport: .udp),
            inboundPeerSockets: inboundPeerSocketCount(
                in: tcp.output,
                processID: processID,
                listeningPorts: Set(portPlan.required.filter { $0.transport == .tcp }.map(\.startPort))
            ),
            inspectionSucceeded: tcp.exitCode == 0 && udp.exitCode == 0
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

    private func listenerPorts(
        in output: String,
        processID: Int32,
        transport: NetworkTransport
    ) -> Set<UInt16> {
        let processMarker = ":\(processID)"
        var ports = Set<UInt16>()
        for line in output.split(separator: "\n").map(String.init) {
            guard line.contains(processMarker) else { continue }
            if transport == .tcp && !line.contains(" LISTEN ") { continue }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count > 3, let port = port(from: String(fields[3])) else { continue }
            ports.insert(port)
        }
        return ports
    }

    private func port(from address: String) -> UInt16? {
        guard let component = address.split(separator: ".").last else { return nil }
        return UInt16(component)
    }

    /// An established socket whose local endpoint is a required listener and
    /// whose remote endpoint is not one of Quilibrium's well-known master
    /// ports is strong evidence that a remote peer initiated the connection.
    private func inboundPeerSocketCount(
        in output: String,
        processID: Int32,
        listeningPorts: Set<UInt16>
    ) -> Int {
        let processMarker = ":\(processID)"
        guard !listeningPorts.isEmpty else { return 0 }
        return output.split(separator: "\n").reduce(into: 0) { count, raw in
            let line = String(raw)
            guard line.contains(processMarker), line.contains(" ESTABLISHED ") else { return }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count > 4,
                let localPort = port(from: String(fields[3])),
                let remotePort = port(from: String(fields[4])),
                listeningPorts.contains(localPort),
                !listeningPorts.contains(remotePort)
            else { return }
            count += 1
        }
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
