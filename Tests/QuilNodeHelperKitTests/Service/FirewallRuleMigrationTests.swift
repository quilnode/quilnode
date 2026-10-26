import XCTest

@testable import QuilNodeHelperKit

final class FirewallRuleMigrationTests: XCTestCase {
    private let current = "/opt/quilibrium/node/node-current"
    private let old = "/opt/quilibrium/node/node-old"

    func testExactRuleParsingDoesNotAcceptSuffixOrUnrecognizedStatus() {
        let output = """
            Total number of apps = 3
            1 : /unexpected/opt/quilibrium/node/node-current
                 (Allow incoming connections)
            2 : /opt/quilibrium/node/node-old
                 (Block incoming connections)
            3 : /opt/quilibrium/node/node-unknown
                 (Unknown state)
            """
        XCTAssertEqual(QuilNodeHelper.firewallRule(for: current, in: output), .missing)
        XCTAssertEqual(QuilNodeHelper.firewallRule(for: old, in: output), .blocked)
        XCTAssertEqual(QuilNodeHelper.firewallRule(for: "/opt/quilibrium/node/node-unknown", in: output), .unavailable)
    }

    func testMigrationRequiresAllowedManagedPathAndMatchingVerifiedIdentifier() {
        let entries: [QuilNodeHelper.FirewallEntry] = [
            .init(path: old, rule: .allowed),
            .init(path: current, rule: .allowed),
            .init(path: "/opt/quilibrium/node/node-blocked", rule: .blocked),
            .init(path: "/opt/quilibrium/node/node-different", rule: .allowed),
            .init(path: "/opt/quilibrium/node/node-unverifiable", rule: .allowed),
            .init(path: "/tmp/node-unrelated", rule: .allowed),
            .init(path: "/opt/quilibrium/node/../node/node-traversal", rule: .allowed),
        ]
        let selected = QuilNodeHelper.staleFirewallRulePaths(for: current, entries: entries) { path in
            if path.hasSuffix("different") { return "different-identifier" }
            if path.hasSuffix("unverifiable") { return nil }
            return "quil-node"
        }
        XCTAssertEqual(selected, [old])
        XCTAssertTrue(QuilNodeHelper.staleFirewallRulePaths(for: current, entries: entries) { _ in nil }.isEmpty)
    }

    func testFailedReplacementRestoresOnlyRemovedAllowedRules() {
        struct Failure: Error {}
        var commands: [String] = []
        XCTAssertThrowsError(
            try QuilNodeHelper.replacingStaleFirewallRules([old]) { option, path in
                commands.append("\(option) \(path)")
            } operation: {
                commands.append("verify replacement")
                throw Failure()
            }
        )
        XCTAssertEqual(commands, ["--remove \(old)", "verify replacement", "--add \(old)", "--unblockapp \(old)"])
    }

    func testSuccessfulReplacementDoesNotRestoreStaleRule() throws {
        var commands: [String] = []
        let result = try QuilNodeHelper.replacingStaleFirewallRules([old]) { option, path in
            commands.append("\(option) \(path)")
        } operation: {
            true
        }
        XCTAssertTrue(result)
        XCTAssertEqual(commands, ["--remove \(old)"])
    }
}
