import Foundation

/// Accept both the Go client's historical banner and the Rust clap banner.
/// Keep the reported version separate from the signed release filename.
public enum QClientVersion {
    public static func parse(_ output: String) -> String? {
        guard output.utf8.count <= 64_000,
            let regex = try? NSRegularExpression(
                pattern:
                    #"(?m)^(?:qclient(?: version:)?[ \t]+)?([0-9]+\.[0-9]+\.[0-9]+(?:-p[0-9]+|(?:\.[0-9]+){1,2}))[ \t\r]*$"#
            )
        else { return nil }
        let matches = regex.matches(in: output, range: NSRange(output.startIndex..., in: output))
        let versions = Set(
            matches.compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: output) else { return nil }
                return String(output[range])
            })
        return versions.count == 1 ? versions.first : nil
    }

    public static func isValid(_ version: String) -> Bool {
        version.count <= 80 && parse(version) == version
    }
}
