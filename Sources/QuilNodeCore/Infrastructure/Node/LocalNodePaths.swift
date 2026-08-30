import Foundation

public struct LocalNodePaths: Sendable {
    public var nodeDirectory: URL
    public var nodeBinary: URL
    public var errorLog: URL

    public init(
        nodeDirectory: URL = URL(fileURLWithPath: "/opt/quilibrium/node", isDirectory: true),
        nodeBinary: URL = URL(fileURLWithPath: "/opt/quilibrium/node/quilibrium-node"),
        errorLog: URL = URL(fileURLWithPath: "/opt/quilibrium/node/node-error.log")
    ) {
        self.nodeDirectory = nodeDirectory
        self.nodeBinary = nodeBinary
        self.errorLog = errorLog
    }
}
