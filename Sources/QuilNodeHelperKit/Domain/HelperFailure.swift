enum HelperFailure: Error, CustomStringConvertible {
    case usage, notRoot, unsafePlist(String), unsafeStage(String), invalidManifest(String)
    case command(String), healthCheck(String), noRollback, migration(String), service(String)
    case unauthorized
    case authorizationRequired(String)

    var description: String {
        switch self {
        case .usage:
            "Usage: QuilNodeHelper <start|stop|restart|rollback> | <install|activate|qclient-install|wallet-transact> <typed-manifest.json> | <bootstrap|migrate> <controller-uid> | serve"
        case .notRoot:
            "QuilNodeHelper must be authorized by macOS before it can manage the node service."
        case let .unsafePlist(reason):
            "Refusing to manage an unsafe LaunchDaemon plist: \(reason)"
        case let .unsafeStage(reason):
            "Refusing an unsafe update staging directory: \(reason)"
        case let .invalidManifest(reason):
            "Refusing an invalid update manifest: \(reason)"
        case let .command(message), let .healthCheck(message): message
        case .noRollback: "No validated QuilNode rollback target is available."
        case let .migration(message): "Migration failed: \(message)"
        case let .service(message): "Passwordless service error: \(message)"
        case .unauthorized: "The local service rejected an unauthenticated request."
        case let .authorizationRequired(message): message
        }
    }
}
