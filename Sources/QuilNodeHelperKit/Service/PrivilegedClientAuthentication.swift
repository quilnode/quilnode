import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func readServiceRequest(_ client: Int32) throws -> PrivilegedServiceRequest {
        var data = Data()
        var byte: UInt8 = 0
        while data.count <= PrivilegedServiceProtocol.maximumRequestBytes {
            let count = Darwin.read(client, &byte, 1)
            guard count == 1 else { break }
            if byte == 0x0a { break }
            data.append(byte)
        }
        guard !data.isEmpty, data.count <= PrivilegedServiceProtocol.maximumRequestBytes else {
            throw HelperFailure.service("request is empty or too large")
        }
        return try JSONDecoder().decode(PrivilegedServiceRequest.self, from: data)
    }

    static func authenticateClient(_ client: Int32, configuration: ServiceConfiguration) throws {
        var peerUID: uid_t = 0
        var peerGID: gid_t = 0
        guard getpeereid(client, &peerUID, &peerGID) == 0,
            peerUID == uid_t(configuration.controllerUID)
        else { throw HelperFailure.unauthorized }

        var auditToken = audit_token_t()
        var auditTokenSize = socklen_t(MemoryLayout<audit_token_t>.size)
        guard getsockopt(client, SOL_LOCAL, LOCAL_PEERTOKEN, &auditToken, &auditTokenSize) == 0,
            auditTokenSize == MemoryLayout<audit_token_t>.size
        else { throw HelperFailure.unauthorized }
        let auditData = withUnsafeBytes(of: &auditToken) { Data($0) }
        let attributes = [kSecGuestAttributeAudit as String: auditData as NSData] as CFDictionary
        var code: SecCode?
        let lookupStatus = SecCodeCopyGuestWithAttributes(nil, attributes, [], &code)
        var requirement: SecRequirement?
        guard
            SecRequirementCreateWithString(
                configuration.controllerRequirement as CFString,
                [],
                &requirement
            ) == errSecSuccess,
            let requirement
        else { throw HelperFailure.unauthorized }

        if lookupStatus == errSecSuccess, let code {
            guard SecCodeCheckValidity(code, SecCSFlags(rawValue: 0), requirement) == errSecSuccess else {
                throw HelperFailure.unauthorized
            }
            return
        }

        // Locally installed ad-hoc LaunchDaemons can be denied dynamic-code
        // lookup. Keep the kernel audit token as the process-instance anchor,
        // resolve its executable path, and validate the complete signed app
        // bundle (including resources and nested code) at that fixed location.
        let expectedExecutable = "/Applications/QuilNode.app/Contents/MacOS/QuilNode"
        let processPathCapacity = 4_096
        var pathBuffer = [CChar](repeating: 0, count: processPathCapacity)
        var tokenForLookup = auditToken
        let pathLength = proc_pidpath_audittoken(
            &tokenForLookup,
            &pathBuffer,
            UInt32(pathBuffer.count)
        )
        let firstProcessPath = pathBuffer.withUnsafeBufferPointer { buffer in
            String(cString: buffer.baseAddress!)
        }
        guard pathLength > 0,
            firstProcessPath == expectedExecutable
        else { throw HelperFailure.unauthorized }

        var staticCode: SecStaticCode?
        let appURL = URL(fileURLWithPath: "/Applications/QuilNode.app", isDirectory: true)
        guard SecStaticCodeCreateWithPath(appURL as CFURL, [], &staticCode) == errSecSuccess,
            let staticCode
        else { throw HelperFailure.unauthorized }
        let strictFlags = SecCSFlags(rawValue: (1 << 0) | (1 << 3) | (1 << 4))
        guard SecStaticCodeCheckValidity(staticCode, strictFlags, requirement) == errSecSuccess else {
            throw HelperFailure.unauthorized
        }

        pathBuffer = [CChar](repeating: 0, count: processPathCapacity)
        tokenForLookup = auditToken
        let secondPathLength = proc_pidpath_audittoken(
            &tokenForLookup,
            &pathBuffer,
            UInt32(pathBuffer.count)
        )
        let secondProcessPath = pathBuffer.withUnsafeBufferPointer { buffer in
            String(cString: buffer.baseAddress!)
        }
        guard secondPathLength > 0,
            secondProcessPath == expectedExecutable
        else { throw HelperFailure.unauthorized }
    }
}
