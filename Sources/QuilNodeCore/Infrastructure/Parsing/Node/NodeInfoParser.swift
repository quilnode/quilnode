import Foundation

public enum NodeInfoParser {
    public static func parse(_ output: String) -> NodeInfo {
        var info = NodeInfo()

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)

            switch key {
            case "Peer ID": info.peerID = value.nilIfEmpty
            case "Legacy Peer ID (Ed448)": info.legacyPeerID = value.nilIfEmpty
            case "Prover Address": info.proverAddress = value.nilIfEmpty
            case "Version": info.version = value.nilIfEmpty
            case "Seniority": info.seniority = Int64(value.numericText) ?? 0
            case "Running Workers": info.runningWorkers = Int(value.numericText) ?? 0
            case "Active Workers": info.activeWorkers = Int(value.numericText) ?? 0
            case "Frame", "Frame Number": info.frame = UInt64(value.numericText) ?? 0
            default: continue
            }
        }

        return info
    }
}
