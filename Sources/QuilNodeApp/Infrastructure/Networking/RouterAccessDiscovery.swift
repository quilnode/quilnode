import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum RouterWebInterfaceStatus: String, Equatable, Sendable {
    case notChecked
    case checking
    case confirmed
    case unconfirmed
    case unavailable
}

struct RouterAccessDiscovery: Equatable, Sendable {
    var routeSignature: String
    var status: RouterWebInterfaceStatus
    var browserURL: URL?
    var checkedAt: Date?
    var title: String
    var detail: String

    static let notChecked = RouterAccessDiscovery(
        routeSignature: "",
        status: .notChecked,
        browserURL: nil,
        checkedAt: nil,
        title: "Gateway not checked",
        detail: "QuilNode has not inspected the active route yet."
    )

    static func checking(route: GatewayRouteAssessment) -> RouterAccessDiscovery {
        .init(
            routeSignature: route.signature,
            status: .checking,
            browserURL: nil,
            checkedAt: nil,
            title: "Checking the gateway",
            detail: "QuilNode is making a short, unauthenticated request to see whether a local web interface responds."
        )
    }
}

/// Performs a conservative, read-only check of the default gateway.
///
/// Discovery never accepts credentials, stores cookies, bypasses certificate
/// validation, follows a gateway to an unrelated host, or attempts UPnP,
/// NAT-PMP, PCP, model fingerprinting, or configuration changes.
actor RouterAccessDiscoverer {
    private final class ProbeDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            // A redirect is already proof that the original gateway spoke
            // HTTP. Do not let discovery leave that original local URL.
            completionHandler(nil)
        }
    }

    private struct CacheEntry {
        var discovery: RouterAccessDiscovery
        var expiresAt: Date
    }

    private let cacheDuration: TimeInterval
    private var cache: [String: CacheEntry] = [:]

    init(cacheDuration: TimeInterval = 10 * 60) {
        self.cacheDuration = cacheDuration
    }

    func discover(route: GatewayRouteAssessment, force: Bool = false) async -> RouterAccessDiscovery {
        let now = Date()
        if !force,
            let cached = cache[route.signature],
            cached.expiresAt > now
        {
            return cached.discovery
        }

        guard route.isSafeBrowserTarget,
            let address = route.address,
            let httpURL = URL(string: "http://\(address)/"),
            let httpsURL = URL(string: "https://\(address)/")
        else {
            return .init(
                routeSignature: route.signature,
                status: .unavailable,
                browserURL: nil,
                checkedAt: now,
                title: route.title,
                detail: route.detail
            )
        }

        // Prefer HTTPS when the gateway presents a certificate macOS trusts.
        // Many residential routers use a self-signed certificate; in that
        // case QuilNode does not bypass validation and falls back to an HTTP
        // response check. The user's browser remains responsible for login.
        if await responds(to: httpsURL, expectedHost: address) {
            return store(
                .init(
                    routeSignature: route.signature,
                    status: .confirmed,
                    browserURL: httpsURL,
                    checkedAt: now,
                    title: "Gateway web service responded",
                    detail:
                        "A secure local web service responded at the macOS default gateway. QuilNode did not sign in or submit credentials."
                ),
                now: now
            )
        }

        if await responds(to: httpURL, expectedHost: address) {
            return store(
                .init(
                    routeSignature: route.signature,
                    status: .confirmed,
                    browserURL: httpURL,
                    checkedAt: now,
                    title: "Gateway web service responded",
                    detail:
                        "A local web service responded at the macOS default gateway. The browser may upgrade to HTTPS or show the gateway's management page."
                ),
                now: now
            )
        }

        return store(
            .init(
                routeSignature: route.signature,
                status: .unconfirmed,
                browserURL: httpURL,
                checkedAt: now,
                title: "Gateway found; web page unconfirmed",
                detail:
                    "The address is local and may still be correct, but no standard web interface answered. The router may require its manufacturer or provider app."
            ),
            now: now
        )
    }

    private func store(_ discovery: RouterAccessDiscovery, now: Date) -> RouterAccessDiscovery {
        cache[discovery.routeSignature] = CacheEntry(
            discovery: discovery,
            expiresAt: now.addingTimeInterval(cacheDuration)
        )
        return discovery
    }

    private func responds(to url: URL, expectedHost: String) async -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2.5
        configuration.timeoutIntervalForResource = 3
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil

        let delegate = ProbeDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("QuilNode router interface discovery", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard data.count <= 2 * 1_024 * 1_024,
                let http = response as? HTTPURLResponse,
                (100...599).contains(http.statusCode)
            else { return false }

            // The delegate prevents discovery from following an unrelated
            // redirect. The button always opens the original local gateway.
            return http.url?.host == expectedHost
        } catch {
            return false
        }
    }
}
