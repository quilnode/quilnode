import CryptoKit
import Darwin
import Foundation
import Security

#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

public enum QuilNodeHelper {
    static let mutationLock = NSLock()
    static let serviceClientSlots = DispatchSemaphore(value: 16)
    static let maximumCommandOutputBytes: off_t = 768 * 1_024
    static let launchctl = URL(fileURLWithPath: "/bin/launchctl")
    static let plistPath = "/Library/LaunchDaemons/com.quilibrium.node.plist"
    static let serviceTarget = "system/com.quilibrium.node"
    static let nodeDirectory = URL(fileURLWithPath: "/opt/quilibrium/node", isDirectory: true)
    static let nodeLink = nodeDirectory.appendingPathComponent("quilibrium-node")
    static let rollbackURL = nodeDirectory.appendingPathComponent(".quilnode-rollback.json")
    static let serviceUser = "_quilnode"
    static let serviceGroup = "_quilnode"
    static let serviceUID: uid_t = 350
    static let serviceGID: gid_t = 350
    static let operatorLabel = "local.quilnode.operator.service"
    static let operatorTarget = "system/local.quilnode.operator.service"
    static let operatorBinary = "/Library/Application Support/QuilNodeService/quilnode-operator"
    static let operatorVerifier = "/Library/Application Support/QuilNodeService/quilnode-release-verifier"
    static let operatorPlist = "/Library/LaunchDaemons/local.quilnode.operator.service.plist"
    static let operatorSupport = "/Library/Application Support/QuilNodeService"
    static let operatorConfig = "/Library/Application Support/QuilNodeService/service.json"
    static let mutationLockPath = "/Library/Application Support/QuilNodeService/mutation.lock"
    static let qclientRoot = URL(fileURLWithPath: "/var/quilibrium/bin/qclient", isDirectory: true)
    static let qclientRecordURL = URL(fileURLWithPath: "/Library/Application Support/QuilNodeService/qclient.json")
    static let firewallRecordURL = URL(
        fileURLWithPath: "/Library/Application Support/QuilNodeService/firewall.json"
    )
    static let nodeUpdatePolicyURL = URL(
        fileURLWithPath: "/Library/Application Support/QuilNodeService/node-update-policy.json"
    )
    static let operatorSocket = "/var/run/quilnode-operator.sock"
    static let permanentAppIdentifier = "com.quilnode.app"
    static let legacyAppIdentifier = "local.quilnode.operator"
    static let walletRoot = nodeDirectory.appendingPathComponent(".quilnode-wallets", isDirectory: true)
    static let walletProfiles = walletRoot.appendingPathComponent("profiles", isDirectory: true)
    static let walletRecovery = walletRoot.appendingPathComponent("recovery", isDirectory: true)
    static let walletRegistryURL = walletRoot.appendingPathComponent("registry.json")
    static let serviceOperations = ServiceOperationCoordinator(
        path: "/Library/Application Support/QuilNodeService/operation.json"
    )

    public static func run() {
        do {
            guard getuid() == 0 else { throw HelperFailure.notRoot }
            guard CommandLine.arguments.count >= 2,
                let action = HelperAction(rawValue: CommandLine.arguments[1])
            else { throw HelperFailure.usage }
            switch action {
            case .start, .stop, .restart:
                guard CommandLine.arguments.count == 2 else { throw HelperFailure.usage }
                try validateLaunchDaemonPlist()
                try withMutationLock { try performLifecycle(action) }
                print("Quilibrium node \(action.rawValue) request completed.")
            case .activate:
                guard CommandLine.arguments.count == 3 else { throw HelperFailure.usage }
                try validateLaunchDaemonPlist()
                try withMutationLock {
                    try activate(manifestPath: CommandLine.arguments[2])
                }
            case .qclientInstall:
                guard CommandLine.arguments.count == 3 else { throw HelperFailure.usage }
                try withMutationLock {
                    try installQClient(manifestPath: CommandLine.arguments[2])
                }
                print("qclient installation completed and root-owned provenance was re-verified.")
            case .walletTransact:
                guard CommandLine.arguments.count == 3 else { throw HelperFailure.usage }
                let configuration = try loadServiceConfiguration()
                let manifest = try readWalletManifest(
                    CommandLine.arguments[2],
                    configuration: configuration
                )
                print(
                    try withMutationLock {
                        try performWalletTransaction(manifest, configuration: configuration)
                    })
            case .install:
                guard CommandLine.arguments.count == 3 else { throw HelperFailure.usage }
                try withMutationLock {
                    try freshInstall(manifestPath: CommandLine.arguments[2])
                }
            case .rollback:
                guard CommandLine.arguments.count == 2 else { throw HelperFailure.usage }
                try validateLaunchDaemonPlist()
                try withMutationLock { try rollback() }
            case .migrate:
                guard CommandLine.arguments.count == 3,
                    let controllerUID = UInt32(CommandLine.arguments[2])
                else { throw HelperFailure.usage }
                try migrate(controllerUID: controllerUID)
            case .bootstrap:
                guard CommandLine.arguments.count == 3,
                    let controllerUID = UInt32(CommandLine.arguments[2])
                else { throw HelperFailure.usage }
                try bootstrap(controllerUID: controllerUID)
            case .serve:
                guard CommandLine.arguments.count == 2 else { throw HelperFailure.usage }
                try serve()
            }
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }
}
