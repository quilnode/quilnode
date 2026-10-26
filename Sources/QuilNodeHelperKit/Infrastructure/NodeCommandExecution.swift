import Foundation

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

extension QuilNodeHelper {
    static func readNodeIdentity() throws -> PrivilegedServiceResponse {
        // --node-info opens a secondary database and can time out while the
        // node is busy. The independent public peer read must survive that.
        let peer = Result { try runNodeTool(["--peer-info"], timeout: 20) }
        let node = Result { try runNodeTool(["--node-info"], timeout: 45) }
        let peerOutput = (try? peer.get()) ?? ""
        let nodeOutput = (try? node.get()) ?? ""
        guard !peerOutput.isEmpty || !nodeOutput.isEmpty else {
            throw HelperFailure.command("Local identity probes did not complete. \(node.failureDescription)")
        }
        return PrivilegedServiceResponse(
            success: true,
            message: nodeOutput.isEmpty
                ? "Public peer identity read; the database-backed node details are temporarily unavailable."
                : "Local node identity read completed.",
            nodePID: currentNodePID(), nodeInfoOutput: nodeOutput, peerInfoOutput: peerOutput
        )
    }

    static func nodeProcessIsRunning() -> Bool {
        guard let output = try? runLaunchctl(["print", serviceTarget]),
            let regex = try? NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)\s*$"#)
        else { return false }
        return regex.firstMatch(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        ) != nil
    }

    static func runNodeTool(_ arguments: [String], timeout: TimeInterval) throws -> String {
        let plist = try? readPlist()
        if plist?["UserName"] as? String == serviceUser {
            return try runAsServiceUser(nodeLink, arguments, timeout: timeout)
        }
        return try run(nodeLink, arguments, timeout: timeout)
    }
}

private extension Result where Success == String {
    var failureDescription: String {
        if case .failure(let error) = self { return String(describing: error) }
        return ""
    }
}
