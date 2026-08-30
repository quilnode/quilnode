import Darwin
import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func serve() throws {
        // Builds 90–92 form the one-way bridge from the early local bundle identifier
        // to the permanent public identifier. The bridge keeps the same pinned
        // certificate and UID; it never broadens authorization to another
        // signer. A later authenticated app update collapses it to the permanent
        // requirement automatically.
        let configuration = try migrateLegacyControllerRequirementIfNeeded(
            try loadServiceConfiguration()
        )
        guard FileManager.default.fileExists(atPath: operatorBinary),
            getuid() == 0
        else { throw HelperFailure.service("the service is not installed securely") }

        signal(SIGPIPE, SIG_IGN)
        unlink(operatorSocket)
        let server = socket(AF_UNIX, SOCK_STREAM, 0)
        guard server >= 0 else { throw HelperFailure.service("socket creation failed") }
        defer {
            close(server)
            unlink(operatorSocket)
        }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let socketPathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard operatorSocket.utf8.count < socketPathCapacity else {
            throw HelperFailure.service("socket path is too long")
        }
        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: socketPathCapacity) {
                _ = strlcpy($0, operatorSocket, socketPathCapacity)
            }
        }
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(server, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0,
            chown(operatorSocket, uid_t(configuration.controllerUID), gid_t(20)) == 0,
            chmod(operatorSocket, 0o600) == 0,
            listen(server, 8) == 0
        else { throw HelperFailure.service("unable to secure or listen on the local socket") }

        while true {
            let client = accept(server, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                throw HelperFailure.service("accept failed")
            }
            // Bound both concurrency and per-client I/O time. Even an
            // authenticated but wedged interface must not accumulate an
            // unbounded number of root-service threads.
            serviceClientSlots.wait()
            DispatchQueue.global(qos: .utility).async {
                autoreleasepool {
                    configureServiceClientTimeouts(client)
                    handleServiceClient(client, configuration: configuration)
                }
                close(client)
                serviceClientSlots.signal()
            }
        }
    }

    static func configureServiceClientTimeouts(_ client: Int32) {
        var receiveTimeout = timeval(tv_sec: 5, tv_usec: 0)
        var sendTimeout = timeval(tv_sec: 15, tv_usec: 0)
        withUnsafePointer(to: &receiveTimeout) {
            _ = setsockopt(
                client, SOL_SOCKET, SO_RCVTIMEO, $0,
                socklen_t(MemoryLayout<timeval>.size)
            )
        }
        withUnsafePointer(to: &sendTimeout) {
            _ = setsockopt(
                client, SOL_SOCKET, SO_SNDTIMEO, $0,
                socklen_t(MemoryLayout<timeval>.size)
            )
        }
    }

    static func handleServiceClient(_ client: Int32, configuration: ServiceConfiguration) {
        let response: PrivilegedServiceResponse
        do {
            try authenticateClient(client, configuration: configuration)
            let request = try readServiceRequest(client)
            guard request.protocolVersion == PrivilegedServiceProtocol.version else {
                throw HelperFailure.service("unsupported protocol version")
            }
            response = try routeServiceRequest(request, configuration: configuration)
        } catch HelperFailure.unauthorized {
            // Authentication failures are intentionally indistinguishable and
            // disclose no process, service-account, capability, or build state.
            response = PrivilegedServiceResponse(
                success: false,
                message: "The local service rejected an unauthenticated request.",
                serviceUser: nil,
                nodePID: nil,
                serviceBuild: nil
            )
        } catch HelperFailure.authorizationRequired(let message) {
            response = PrivilegedServiceResponse(
                success: false,
                message: message,
                nodePID: currentNodePID(),
                authorizationRequired: true
            )
        } catch {
            response = PrivilegedServiceResponse(success: false, message: "\(error)", nodePID: currentNodePID())
        }
        if var data = try? JSONEncoder().encode(response) {
            data.append(0x0a)
            data.withUnsafeBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                var written = 0
                while written < bytes.count {
                    let count = Darwin.write(
                        client,
                        baseAddress.advanced(by: written),
                        bytes.count - written
                    )
                    if count <= 0 { break }
                    written += count
                }
            }
        }
    }
}
