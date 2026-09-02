import Foundation

/// Builds user-initiated links to public identity pages.
///
/// This type only constructs browser destinations. It must not perform network
/// requests, install an agent, or participate in local node observation.
enum IdentityExplorerLink {
    private static let peerPage = URL(string: "https://quilscan.com/peer")!
    private static let proverPage = URL(string: "https://quilscan.com/rings")!
    private static let maximumIdentifierLength = 256
    private static let identifierCharacters = CharacterSet.alphanumerics

    static func peer(_ value: String?) -> URL? {
        guard let value = validatedIdentifier(value) else { return nil }
        return peerPage.appendingPathComponent(value, isDirectory: false)
    }

    static func prover(_ value: String?) -> URL? {
        guard let value = validatedIdentifier(value) else { return nil }
        var components = URLComponents(url: proverPage, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "prover", value: value)]
        return components?.url
    }

    private static func validatedIdentifier(_ value: String?) -> String? {
        guard let value,
            !value.isEmpty,
            value.count <= maximumIdentifierLength,
            value.unicodeScalars.allSatisfy(identifierCharacters.contains)
        else { return nil }
        return value
    }
}
