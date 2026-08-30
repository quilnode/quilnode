import Foundation

public enum LocalRegistryParser {
    public static func parse(_ line: String) -> LocalRegistryEvidence? {
        let isSnapshot = line.contains("local prover appeared in registry")
        let isChange = line.contains("local prover seniority changed")
        guard (isSnapshot || isChange),
            let brace = line.firstIndex(of: "{"),
            let data = String(line[brace...]).data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else { return nil }

        let address = dictionary["address"] as? String
        let seniority =
            int64(
                dictionary[isChange ? "new" : "seniority"]
            ) ?? 0
        let previousSeniority = isChange ? int64(dictionary["prev"]) : nil
        let timestamp = line.split(separator: "\t", maxSplits: 1).first
            .flatMap { ISO8601DateFormatter().date(from: String($0)) }
        return LocalRegistryEvidence(
            proverAddress: address,
            seniority: seniority,
            previousSeniority: previousSeniority,
            allocations: NodeStatusParser.int(dictionary, "allocations"),
            status: dictionary["status"] as? String,
            observedAt: timestamp,
            kind: isChange ? .valueChanged : .registrySnapshot
        )
    }

    /// Returns the newest registry observation in a log window. Keeping this
    /// selection in the parser makes the collector's incremental-tail path
    /// deterministic and independently testable.
    public static func latest(in text: String) -> LocalRegistryEvidence? {
        for line in text.split(separator: "\n").reversed() {
            if let evidence = parse(String(line)) { return evidence }
        }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber { return number.int64Value }
        if let string = value as? String { return Int64(string) }
        return nil
    }
}
