import Foundation

class BoundedDownloadState<Value>: NSObject, @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var completed = false
    private var storedResult: Result<Value, Error> = .failure(UpdateCenterError.downloadFailed)

    var result: Result<Value, Error> {
        lock.lock()
        defer { lock.unlock() }
        return storedResult
    }

    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        storedResult = result
        lock.unlock()
        semaphore.signal()
    }

    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }

    func matches(_ actual: URL?, expected: URL) -> Bool {
        actual?.scheme == expected.scheme
            && actual?.host == expected.host
            && actual?.port == expected.port
            && actual?.path == expected.path
            && actual?.query == expected.query
    }
}

final class BoundedDataDownloadDelegate: BoundedDownloadState<(Data, HTTPURLResponse)>, URLSessionDataDelegate,
    URLSessionTaskDelegate, @unchecked Sendable
{
    private let expectedURL: URL
    private let maximumBytes: Int
    private let acceptedStatusCodes: Set<Int>
    private let dataLock = NSLock()
    private var received = Data()
    private var acceptedResponse: HTTPURLResponse?

    init(expectedURL: URL, maximumBytes: Int, acceptedStatusCodes: Set<Int>) {
        self.expectedURL = expectedURL
        self.maximumBytes = maximumBytes
        self.acceptedStatusCodes = acceptedStatusCodes
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse,
            acceptedStatusCodes.contains(http.statusCode),
            matches(http.url, expected: expectedURL),
            response.expectedContentLength <= Int64(maximumBytes)
                || response.expectedContentLength == NSURLSessionTransferSizeUnknown
        else {
            completionHandler(.cancel)
            finish(.failure(UpdateCenterError.downloadFailed))
            return
        }
        acceptedResponse = http
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        dataLock.lock()
        guard received.count <= maximumBytes - data.count else {
            dataLock.unlock()
            dataTask.cancel()
            finish(.failure(UpdateCenterError.downloadFailed))
            return
        }
        received.append(data)
        dataLock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
            return
        }
        dataLock.lock()
        let data = received
        let response = acceptedResponse
        dataLock.unlock()
        // A successful metadata document must contain bytes. HTTP 304 is the
        // deliberate exception: its empty body proves the prior entity is unchanged.
        guard let response,
            boundedResponseBodyIsValid(statusCode: response.statusCode, data: data),
            data.count <= maximumBytes
        else {
            finish(.failure(UpdateCenterError.downloadFailed))
            return
        }
        finish(.success((data, response)))
    }
}

final class BoundedFileDownloadDelegate: BoundedDownloadState<Void>, URLSessionDownloadDelegate,
    URLSessionTaskDelegate, @unchecked Sendable
{
    private let expectedURL: URL
    private let destination: URL
    private let maximumBytes: Int64

    init(expectedURL: URL, destination: URL, maximumBytes: Int) {
        self.expectedURL = expectedURL
        self.destination = destination
        self.maximumBytes = Int64(maximumBytes)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesWritten > maximumBytes
            || (totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown
                && totalBytesExpectedToWrite > maximumBytes)
        {
            downloadTask.cancel()
            finish(.failure(UpdateCenterError.downloadFailed))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let http = downloadTask.response as? HTTPURLResponse,
            http.statusCode == 200,
            matches(http.url, expected: expectedURL),
            let size = try? location.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size > 0, Int64(size) <= maximumBytes,
            !FileManager.default.fileExists(atPath: destination.path)
        else {
            finish(.failure(UpdateCenterError.downloadFailed))
            return
        }
        do {
            try FileManager.default.copyItem(at: location, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            finish(.success(()))
        } catch {
            try? FileManager.default.removeItem(at: destination)
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
    }
}
