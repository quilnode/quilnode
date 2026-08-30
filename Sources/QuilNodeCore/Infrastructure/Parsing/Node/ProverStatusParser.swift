import Foundation

public enum ProverStatusParser {
    public static func parse(_ output: String) -> LocalProverStatus? {
        var result = LocalProverStatus()
        var allocations: [ShardAllocation] = []
        var currentAllocation: Int?
        var sawStatus = false

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if let allocation = parseAllocation(line) {
                allocations.append(allocation)
                currentAllocation = allocations.count - 1
                sawStatus = true
                continue
            }

            if let index = currentAllocation {
                if line.hasPrefix("Action:") {
                    allocations[index].action = value(after: "Action:", in: line)
                    continue
                }
                if line.hasPrefix("Re-confirm") {
                    allocations[index].action = line
                    continue
                }
                if line.hasPrefix("Join Frame:") {
                    allocations[index].joinFrame = firstUInt(after: "Join Frame:", in: line)
                    allocations[index].confirmFrame = firstUInt(after: "Confirm Frame:", in: line)
                    continue
                }
                if line.hasPrefix("Last Active:") {
                    allocations[index].lastActiveFrame = firstUInt(after: "Last Active:", in: line)
                    continue
                }
            }

            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
            switch key {
            case "Seniority":
                result.seniority = Int64(value.numericText) ?? 0
                sawStatus = true
            case "Peer Score": result.peerScore = Double(value)
            case "Running Workers": result.runningWorkers = Int(value.numericText) ?? 0
            case "Allocated Workers": result.allocatedWorkers = Int(value.numericText) ?? 0
            case "Last Received": result.lastReceivedFrame = UInt64(value.numericText) ?? 0
            case "Last Global Head": result.lastGlobalHeadFrame = UInt64(value.numericText) ?? 0
            case "Reachable": result.reachable = parseBool(value)
            case "Epoch":
                result.epoch = UInt64(value.split(whereSeparator: \.isWhitespace).first ?? "") ?? 0
                result.epochLength = firstUInt(after: "length", in: value) ?? 720
                result.nextEpochFrame = firstUInt(after: "frame", in: value) ?? 0
            default: continue
            }
        }

        result.allocations = allocations
        return sawStatus ? result : nil
    }

    private static func parseAllocation(_ line: String) -> ShardAllocation? {
        let pattern = #"^\[([0-9]+)\]\s+Filter:\s+([0-9a-fA-F]+)\s+Status:\s+([^\s]+)(?:\s+Worker:\s+(.+))?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
            let indexRange = Range(match.range(at: 1), in: line),
            let filterRange = Range(match.range(at: 2), in: line),
            let statusRange = Range(match.range(at: 3), in: line),
            let index = Int(line[indexRange])
        else { return nil }
        let worker = Range(match.range(at: 4), in: line).map { String(line[$0]) }
        return ShardAllocation(
            index: index,
            filter: String(line[filterRange]),
            status: String(line[statusRange]),
            worker: worker
        )
    }

    private static func value(after marker: String, in text: String) -> String? {
        guard let range = text.range(of: marker) else { return nil }
        let value = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func firstUInt(after marker: String, in text: String) -> UInt64? {
        guard let value = value(after: marker, in: text),
            let regex = try? NSRegularExpression(pattern: #"[0-9]+"#),
            let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
            let range = Range(match.range, in: value)
        else { return nil }
        return UInt64(value[range])
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "yes", "reachable": true
        case "false", "no", "unreachable": false
        default: nil
        }
    }
}
