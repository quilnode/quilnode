import Foundation

public struct OfficialNodeRelease: Equatable, Sendable {
    public var version: String
    public var digestPublished: Bool
    public var signatureCount: Int

    public init(version: String, digestPublished: Bool, signatureCount: Int) {
        self.version = version
        self.digestPublished = digestPublished
        self.signatureCount = signatureCount
    }
}

public enum ReleaseManifestParser {
    public static func latest(
        in manifest: String,
        platform: String = "darwin-arm64"
    ) -> OfficialNodeRelease? {
        let escapedPlatform = NSRegularExpression.escapedPattern(for: platform)
        let pattern = #"node-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)-"# + escapedPlatform
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(manifest.startIndex..., in: manifest)
        let versions = regex.matches(in: manifest, range: range).compactMap { match -> String? in
            guard let valueRange = Range(match.range(at: 1), in: manifest) else { return nil }
            return String(manifest[valueRange])
        }
        guard let latestVersion = Set(versions).max(by: versionIsOlder) else { return nil }

        let base = "node-\(latestVersion)-\(platform)"
        let lines = manifest.split(whereSeparator: \.isNewline).map(String.init)
        return OfficialNodeRelease(
            version: latestVersion,
            digestPublished: lines.contains("\(base).dgst"),
            signatureCount: lines.filter { $0.hasPrefix("\(base).dgst.sig.") }.count
        )
    }

    private static func versionIsOlder(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        return left.lexicographicallyPrecedes(right)
    }
}
