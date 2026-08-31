import Foundation

struct BoundedDownloadProgress: Equatable, Sendable {
    let bytesReceived: Int64
    let totalBytes: Int64?

    var fraction: Double? {
        guard let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(bytesReceived) / Double(totalBytes), 0), 1)
    }

    var byteDescription: String {
        let received = ByteCountFormatter.string(
            fromByteCount: max(bytesReceived, 0),
            countStyle: .file
        )
        guard let totalBytes, totalBytes > 0 else { return received }
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(received) of \(total)"
    }
}

func boundedResponseBodyIsValid(statusCode: Int, data: Data) -> Bool {
    statusCode == 304 || !data.isEmpty
}

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension ReleaseChecker {
    nonisolated static func downloadSynchronously(
        _ url: URL,
        to destination: URL,
        maximumBytes: Int,
        resourceTimeout: TimeInterval = 30 * 60,
        progress: (@Sendable (BoundedDownloadProgress) -> Void)? = nil
    ) throws {
        guard maximumBytes > 0, resourceTimeout > 0,
            !FileManager.default.fileExists(atPath: destination.path)
        else { throw UpdateCenterError.downloadFailed }
        let delegate = BoundedFileDownloadDelegate(
            expectedURL: url,
            destination: destination,
            maximumBytes: maximumBytes,
            progress: progress
        )
        let session = URLSession(
            configuration: ephemeralConfiguration(resourceTimeout: resourceTimeout),
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: url)
        task.resume()
        guard delegate.wait(timeout: resourceTimeout) else {
            task.cancel()
            throw UpdateCenterError.downloadTimedOut
        }
        try delegate.result.get()
    }

    nonisolated static func downloadGitHubMediaSynchronously(
        _ url: URL,
        to destination: URL,
        maximumBytes: Int
    ) throws {
        guard url.scheme == "https",
            url.host == "media.githubusercontent.com",
            url.path.hasPrefix("/media/QuilibriumNetwork/monorepo/")
        else { throw UpdateCenterError.downloadFailed }
        guard !FileManager.default.fileExists(atPath: destination.path)
        else { throw UpdateCenterError.downloadFailed }
        let delegate = BoundedFileDownloadDelegate(
            expectedURL: url,
            destination: destination,
            maximumBytes: maximumBytes
        )
        let session = URLSession(
            configuration: ephemeralConfiguration(resourceTimeout: 30 * 60),
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }
        let task = session.downloadTask(with: url)
        task.resume()
        guard delegate.wait(timeout: 30 * 60) else {
            task.cancel()
            throw UpdateCenterError.downloadTimedOut
        }
        try delegate.result.get()
    }

    nonisolated static func ephemeralConfiguration(
        resourceTimeout: TimeInterval = 10 * 60
    ) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = resourceTimeout
        config.waitsForConnectivity = false
        return config
    }

    nonisolated static func ephemeralSession() -> URLSession {
        URLSession(configuration: ephemeralConfiguration())
    }

    /// Small release manifests must fail fast. Artifact downloads use the
    /// longer-lived session above, while metadata cannot hold the Update
    /// Center in a checking state for minutes through a slow trickle response.
    nonisolated static func metadataSession() -> URLSession {
        let config = ephemeralConfiguration(resourceTimeout: 30)
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config)
    }

    nonisolated static func downloadBoundedDataSynchronously(
        _ request: URLRequest,
        maximumBytes: Int,
        timeout: TimeInterval,
        acceptedStatusCodes: Set<Int> = [200]
    ) throws -> (Data, HTTPURLResponse) {
        guard let expectedURL = request.url, maximumBytes > 0, !acceptedStatusCodes.isEmpty else {
            throw UpdateCenterError.downloadFailed
        }
        let delegate = BoundedDataDownloadDelegate(
            expectedURL: expectedURL,
            maximumBytes: maximumBytes,
            acceptedStatusCodes: acceptedStatusCodes
        )
        let configuration = ephemeralConfiguration(resourceTimeout: timeout)
        configuration.timeoutIntervalForRequest = min(timeout, 15)
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: request)
        task.resume()
        guard delegate.wait(timeout: timeout) else {
            task.cancel()
            throw UpdateCenterError.downloadTimedOut
        }
        return try delegate.result.get()
    }

    nonisolated static func exactReleaseURL(_ url: URL?, path: String) -> Bool {
        url?.scheme == "https" && url?.host == "releases.quilibrium.com" && url?.path == path
    }

    nonisolated static func httpDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter.date(from: value)
    }
}
