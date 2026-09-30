import XCTest

@testable import QuilNodeHelperKit

final class ServiceLifecycleTests: XCTestCase {
    private let bootout = ["bootout", "system", "/Library/LaunchDaemons/com.quilibrium.node.plist"]
    private let bootstrap = ["bootstrap", "system", "/Library/LaunchDaemons/com.quilibrium.node.plist"]

    func testRestartReregistersTheJobAndItsLaunchRequirement() throws {
        XCTAssertEqual(
            try QuilNodeHelper.lifecycleCommands(.restart, loaded: true, running: true), [bootout, bootstrap])
    }

    func testStartRecoversALoadedJobWithoutAProcess() throws {
        XCTAssertEqual(
            try QuilNodeHelper.lifecycleCommands(.start, loaded: true, running: false), [bootout, bootstrap])
    }

    func testStartDoesNotInterruptARunningNode() throws {
        XCTAssertEqual(try QuilNodeHelper.lifecycleCommands(.start, loaded: true, running: true), [])
    }

    func testUnloadedStartAndRestartBootstrapDirectly() throws {
        for action: HelperAction in [.start, .restart] {
            XCTAssertEqual(try QuilNodeHelper.lifecycleCommands(action, loaded: false, running: false), [bootstrap])
        }
    }

    func testStopOnlyUnloadsTheFixedNodeJob() throws {
        XCTAssertEqual(try QuilNodeHelper.lifecycleCommands(.stop, loaded: true, running: true), [bootout])
        XCTAssertEqual(try QuilNodeHelper.lifecycleCommands(.stop, loaded: false, running: false), [])
        XCTAssertThrowsError(try QuilNodeHelper.lifecycleCommands(.activate, loaded: true, running: true))
    }
}
