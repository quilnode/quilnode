import Foundation
import QuilNodeShared

extension LocalNodeCollector {
    func readTail(_ url: URL, maximumBytes: UInt64) -> String? {
        guard
            let data = try? BoundedLocalData.readTail(
                from: url,
                maximumFileBytes: .max,
                maximumTailBytes: Int(maximumBytes),
                allowGrowth: true
            )
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    func readLatestRegistryEvidence(_ url: URL) -> LocalRegistryEvidence? {
        // A busy prover can emit tens of megabytes per hour. This cold-start
        // path stops as soon as it finds the newest usable evidence.
        try? BoundedLocalData.firstMatchInReverseTail(
            from: url,
            maximumFileBytes: .max,
            maximumScanBytes: 128 * 1_024 * 1_024,
            chunkBytes: 8 * 1_024 * 1_024
        ) { data in
            LocalRegistryParser.latest(in: String(decoding: data, as: UTF8.self))
        }
    }

    func readLatestRewardCredit(_ url: URL) -> RewardCreditEvidence? {
        try? BoundedLocalData.firstMatchInReverseTail(
            from: url,
            maximumFileBytes: .max,
            maximumScanBytes: 32 * 1_024 * 1_024,
            chunkBytes: 8 * 1_024 * 1_024
        ) { data in
            latestRewardCredit(in: String(decoding: data, as: UTF8.self))
        }
    }

    func readLatestArchiveEndpointCount(_ url: URL) -> Int? {
        try? BoundedLocalData.firstMatchInReverseTail(
            from: url,
            maximumFileBytes: .max,
            maximumScanBytes: 8 * 1_024 * 1_024,
            chunkBytes: 1 * 1_024 * 1_024
        ) { data in
            ArchiveEndpointLogParser.latestCount(in: String(decoding: data, as: UTF8.self))
        }
    }

    func latestRewardCredit(in text: String) -> RewardCreditEvidence? {
        for line in text.split(separator: "\n").reversed() {
            let value = String(line)
            guard value.contains("reward credited to local prover") else { continue }
            guard let frame = capture(#"\"frame\":([0-9]+)"#, in: value).flatMap(UInt64.init),
                let balance = capture(#"\"new_balance\":\"?([0-9]+)\"?"#, in: value)
            else { continue }
            let timestamp = value.split(separator: "\t", maxSplits: 1).first.map(String.init)
            let date = timestamp.flatMap { ISO8601DateFormatter().date(from: $0) }
            return RewardCreditEvidence(frame: frame, balanceSubunits: balance, date: date)
        }
        return nil
    }

    private func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
