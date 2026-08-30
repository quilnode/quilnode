import Foundation
import QuilNodeShared

extension LocalNodeCollector {
    func runningNodePID() -> Int32? {
        let service = run(
            executable: URL(fileURLWithPath: "/bin/launchctl"),
            arguments: ["print", "system/com.quilibrium.node"],
            timeout: 2
        )
        if service.exitCode == 0,
            let regex = try? NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)\s*$"#),
            let match = regex.firstMatch(
                in: service.output,
                range: NSRange(service.output.startIndex..., in: service.output)
            ),
            let range = Range(match.range(at: 1), in: service.output),
            let pid = Int32(service.output[range])
        {
            return pid
        }

        // Match the exact daemon command so short-lived diagnostic clients
        // are never mistaken for the managed service process.
        let fallback = run(
            executable: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-f", "^/opt/quilibrium/node/quilibrium-node$"],
            timeout: 2
        )
        guard fallback.exitCode == 0 else { return nil }
        return fallback.output.split(whereSeparator: \.isWhitespace).compactMap { Int32($0) }.first
    }

    func readNodeInfo() -> NodeInfo? {
        if let privilegedInfo = PrivilegedServiceClient.readNodeInfo() {
            return privilegedInfo
        }
        guard FileManager.default.isExecutableFile(atPath: paths.nodeBinary.path) else {
            return nil
        }
        let result = run(
            executable: paths.nodeBinary,
            arguments: ["--node-info"],
            currentDirectory: paths.nodeDirectory,
            timeout: 15
        )
        var info = NodeInfoParser.parse(result.output)
        let peerResult = run(
            executable: paths.nodeBinary,
            arguments: ["--peer-info"],
            currentDirectory: paths.nodeDirectory,
            timeout: 10
        )
        let peerInfo = NodeInfoParser.parse(peerResult.output)
        info.legacyPeerID = peerInfo.legacyPeerID
        return info.version == nil && info.peerID == nil && info.proverAddress == nil ? nil : info
    }

    func readMetrics() -> String {
        // Prefer the loopback endpoint so newly added upstream metrics are not
        // hidden by an older installed helper response schema.
        let direct = run(
            executable: paths.nodeBinary,
            arguments: ["--metrics"],
            currentDirectory: paths.nodeDirectory,
            timeout: 3
        ).output
        if !direct.isEmpty, direct.contains("libp2p_connected_peers") {
            return direct
        }
        if let metrics = PrivilegedServiceClient.readMetrics(), !metrics.isEmpty {
            return metrics
        }
        return direct
    }

    func readProcessStats(pid: Int32) -> ProcessStats? {
        let result = run(
            executable: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-p", String(pid), "-o", "%cpu=,rss=,etime=,time="],
            timeout: 2
        )
        guard result.exitCode == 0 else { return nil }
        let fields = result.output.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 4 else { return nil }
        let cpu = Double(fields[0])
        let rssKB = Double(fields[1])
        return ProcessStats(
            cpuPercent: cpu,
            cpuTimeSeconds: ProcessCPUTimeParser.parse(String(fields[3])),
            sampledAt: Date(),
            memoryMB: rssKB.map { $0 / 1024 },
            elapsed: String(fields[2])
        )
    }

    func fileModifiedAt(_ url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        timeout: TimeInterval
    ) -> CommandResult {
        let result = BoundedCommandRunner.run(
            executable: executable.path,
            arguments: arguments,
            currentDirectory: currentDirectory,
            timeout: timeout
        )
        return CommandResult(output: result.output, exitCode: result.exitCode)
    }
}
