import Foundation

public enum ProtocolEventLogParser {
    /// Records only explicit successful reset messages. Merely reaching a
    /// target frame is not treated as proof that the local transition applied.
    public static func observations(in text: String) -> [String: UInt64] {
        let eventPattern = try! NSRegularExpression(
            pattern: #"(?i)(grid|prover)-reset\s+v([0-9]+):\s+prover-tree\s+wiped\s*\+\s*rebuilt"#
        )
        let framePattern = try! NSRegularExpression(pattern: #"\"frame\"\s*:\s*([0-9]+)"#)
        var observations: [String: UInt64] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            let range = NSRange(line.startIndex..., in: line)
            guard let event = eventPattern.firstMatch(in: line, range: range),
                let familyRange = Range(event.range(at: 1), in: line),
                let versionRange = Range(event.range(at: 2), in: line),
                let frameMatch = framePattern.firstMatch(in: line, range: range),
                let frameRange = Range(frameMatch.range(at: 1), in: line),
                let frame = UInt64(line[frameRange])
            else { continue }
            let family = line[familyRange].uppercased()
            let version = line[versionRange]
            observations["QUIL_\(family)_RESET_V\(version)_FRAME"] = frame
        }
        return observations
    }
}
