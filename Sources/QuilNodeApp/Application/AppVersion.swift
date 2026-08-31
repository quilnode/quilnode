import Foundation

/// Presentation only: Sparkle continues to order updates by CFBundleVersion.
/// macOS requires the short bundle version to be numeric, so prerelease labels
/// live in a separate, sealed Info.plist property shared with release tooling.
struct AppVersion: Equatable {
    let displayVersion: String
    let build: String

    static var current: Self { Self(info: Bundle.main.infoDictionary ?? [:]) }

    init(info: [String: Any]) {
        displayVersion = Self.text(info["QuilNodeReleaseVersion"])
            ?? Self.text(info["CFBundleShortVersionString"])
            ?? "Development"
        build = Self.text(info["CFBundleVersion"]) ?? "—"
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
