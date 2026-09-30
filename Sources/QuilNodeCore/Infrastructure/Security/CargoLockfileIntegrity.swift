import Foundation

/// Allows Cargo to reconcile local dependency edges without changing any
/// external package record, package identity, or other lockfile metadata.
public enum CargoLockfileIntegrity {
    public static func permitsLocalDependencyRepair(upstream: Data, resolved: Data) -> Bool {
        guard let original = records(upstream), let candidate = records(resolved) else { return false }
        return original.header == candidate.header
            && original.external == candidate.external
            && original.local == candidate.local
    }

    private static func records(_ data: Data) -> (header: String, external: [String], local: [String])? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let sections = text.components(separatedBy: "\n[[package]]\n")
        guard sections.count > 1,
            sections[0].split(separator: "\n").contains(where: { $0 == "version = 3" || $0 == "version = 4" })
        else { return nil }
        var external: [String] = []
        var local: [String] = []
        for section in sections.dropFirst() {
            let lines = section.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
            guard lines.count >= 2, lines[0].hasPrefix("name = \""), lines[1].hasPrefix("version = \""),
                !lines.contains(where: { $0.hasPrefix("[") })
            else { return nil }
            if lines.contains(where: { $0.hasPrefix("source = ") }) {
                external.append(lines.joined(separator: "\n"))
                continue
            }
            var metadata: [String] = []
            var inDependencies = false
            var sawDependencies = false
            for line in lines {
                if line == "dependencies = [" {
                    guard !inDependencies, !sawDependencies else { return nil }
                    inDependencies = true
                    sawDependencies = true
                } else if inDependencies {
                    if line == "]" {
                        inDependencies = false
                    } else {
                        // Cargo-generated dependency arrays contain one quoted
                        // identifier per line; reject unknown TOML constructs.
                        guard line.hasPrefix(" \""), line.hasSuffix("\","),
                            !line.dropFirst(2).dropLast(2).contains("\"")
                        else { return nil }
                    }
                } else {
                    metadata.append(line)
                }
            }
            guard !inDependencies else { return nil }
            local.append(metadata.joined(separator: "\n"))
        }
        return (sections[0], external.sorted(), local.sorted())
    }
}
