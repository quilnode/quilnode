import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

/// Creates short-lived, owner-only manifests for the authenticated wallet
/// service. Key material is never staged here; manifests contain capabilities
/// and operator intent only.
struct WalletTransactionStaging {
    private let fileManager: FileManager
    private let rootDirectory: URL

    init(
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        self.rootDirectory =
            rootDirectory
            ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/QuilNode/WalletStaging", isDirectory: true)
    }

    func makeDirectory() throws -> URL {
        try PrivateLocalFileSystem.ensureDirectory(at: rootDirectory)
        let directory = rootDirectory.appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        try PrivateLocalFileSystem.createExclusiveDirectory(at: directory)
        return directory
    }

    func write(_ manifest: WalletTransactionManifest, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("wallet-transaction.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try PrivateLocalFileSystem.write(try encoder.encode(manifest), atomicallyTo: url)
        return url
    }

    func remove(_ directory: URL) {
        try? fileManager.removeItem(at: directory)
    }
}
