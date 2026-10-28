import Foundation
import XCTest

@testable import QuilNodeApp

final class UpdateSignalSchedulingTests: XCTestCase {
    @MainActor
    func testReschedulingReleasesCancelledProbeAndRejectsItsLateCompletion() async throws {
        let (checker, defaults, suite) = fixture()
        defer {
            stop(checker)
            defaults.removePersistentDomain(forName: suite)
        }
        let gate = SignalProbeGate()
        checker.signalProbe = { _, _, _, _ in await gate.probe() }
        checker.beginSignalCheck()
        let oldTask = try XCTUnwrap(checker.signalCheckTask)
        try await waitForProbes(1, gate: gate)

        checker.rescheduleAutomaticChecks(runImmediately: false)
        XCTAssertNil(checker.signalCheckTask, "A cancelled task must not block every future signal check.")
        checker.beginSignalCheck()
        let generation = checker.signalGeneration
        // Complete the obsolete probe after its replacement has been scheduled.
        await gate.finishFirst(fingerprint: "obsolete")
        await oldTask.value
        XCTAssertEqual(checker.signalGeneration, generation)
        XCTAssertNil(checker.lastSignalCheck)
        XCTAssertNil(checker.loadSignalBaseline(for: checker.policy))
        guard checker.signalCheckTask != nil else {
            XCTFail("The obsolete completion must not clear the replacement task.")
            return
        }
        try await waitForProbes(1, gate: gate)
        let replacement = try XCTUnwrap(checker.signalCheckTask)
        await gate.finishFirst(fingerprint: "current")
        await replacement.value
        XCTAssertNil(checker.signalCheckTask)
        XCTAssertEqual(checker.loadSignalBaseline(for: checker.policy)?.fingerprint, "current")
        XCTAssertNotNil(checker.nextSignalCheck)
    }

    @MainActor
    func testSuccessfulUnchangedProbeClearsTransientFailureBackoff() async throws {
        let (checker, defaults, suite) = fixture()
        defer {
            stop(checker)
            defaults.removePersistentDomain(forName: suite)
        }
        checker.signalFailureCount = 4
        checker.signalCheckError = "Temporary network failure"
        checker.signalProbe = { _, _, _, _ in
            .init(result: .unchanged, fingerprint: "current", entityTag: nil)
        }
        checker.beginSignalCheck()
        await checker.signalCheckTask?.value
        XCTAssertEqual(checker.signalFailureCount, 0)
        XCTAssertNil(checker.signalCheckError)
        let delay = try XCTUnwrap(checker.nextSignalCheck).timeIntervalSinceNow
        XCTAssertGreaterThan(delay, 290)
        XCTAssertLessThanOrEqual(delay, 330)
    }

    @MainActor
    func testSwitchingToManualClearsTasksAndIgnoresLateResult() async throws {
        let (checker, defaults, suite) = fixture()
        defer {
            stop(checker)
            defaults.removePersistentDomain(forName: suite)
        }
        let gate = SignalProbeGate()
        checker.signalProbe = { _, _, _, _ in await gate.probe() }
        checker.beginSignalCheck()
        let task = try XCTUnwrap(checker.signalCheckTask)
        try await waitForProbes(1, gate: gate)
        checker.policy = .manual
        checker.rescheduleAutomaticChecks(runImmediately: false)
        await gate.finishFirst(fingerprint: "obsolete")
        await task.value
        XCTAssertNil(checker.signalCheckTask)
        XCTAssertNil(checker.signalTask)
        XCTAssertNil(checker.automationTask)
        XCTAssertNil(checker.nextSignalCheck)
        XCTAssertNil(checker.nextAutomaticCheck)
        XCTAssertNil(checker.lastSignalCheck)
    }

    @MainActor
    func testSignalSuccessPreservesFullReconciliationBackoff() async {
        let (checker, defaults, suite) = fixture()
        defer {
            stop(checker)
            defaults.removePersistentDomain(forName: suite)
        }
        checker.reconciliationFailureCount = 3
        checker.signalProbe = { _, _, _, _ in
            .init(result: .unchanged, fingerprint: "current", entityTag: nil)
        }
        checker.beginSignalCheck()
        await checker.signalCheckTask?.value
        XCTAssertEqual(checker.reconciliationFailureCount, 3)
        XCTAssertGreaterThan(checker.nextSignalCheck?.timeIntervalSinceNow ?? 0, 2_390)
    }

    @MainActor
    func testExplicitRetryClearsSuppressionButBusyRequestsDoNot() async {
        let (checker, defaults, suite) = fixture()
        defer {
            stop(checker)
            defaults.removePersistentDomain(forName: suite)
        }
        let key = "node-update-automatic-failure-candidate-v1"
        checker.rememberAutomaticFailure(for: "approved:fixture")
        checker.operation = .activating
        checker.requestAutomaticCheck()
        XCTAssertNotNil(defaults.string(forKey: key))
        checker.operation = .idle
        checker.requestAutomaticCheck()
        checker.cancelCheck()
        await checker.checkTask?.value
        XCTAssertNil(defaults.string(forKey: key))
    }

    @MainActor
    func testStatusDoesNotCallOverdueOrFailedDiscoveryReady() {
        let (checker, defaults, suite) = fixture()
        defer {
            stop(checker)
            defaults.removePersistentDomain(forName: suite)
        }
        checker.automaticAuthorizationState = .ready
        checker.nextSignalCheck = Date().addingTimeInterval(-3_600)
        XCTAssertTrue(checker.automaticDiscoveryStatus().contains("overdue"))
        checker.nextSignalCheck = Date().addingTimeInterval(300)
        checker.signalCheckError = "Offline"
        XCTAssertTrue(checker.automaticDiscoveryStatus().contains("retry"))
        checker.signalCheckError = nil
        XCTAssertTrue(checker.automaticDiscoveryStatus().contains("ready"))
    }

    @MainActor
    private func fixture() -> (ReleaseChecker, UserDefaults, String) {
        let suite = "QuilNode.UpdateSignalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let checker = ReleaseChecker(preview: (), defaults: defaults)
        checker.policy = .approvedDevelopment
        return (checker, defaults, suite)
    }

    @MainActor
    private func stop(_ checker: ReleaseChecker) {
        checker.policy = .manual
        checker.rescheduleAutomaticChecks(runImmediately: false)
    }

    @MainActor
    private func waitForProbes(_ count: Int, gate: SignalProbeGate) async throws {
        for _ in 0..<200 {
            if await gate.waitingCount == count { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("The probe did not start.")
    }
}

private actor SignalProbeGate {
    private var pending: [CheckedContinuation<UpdateSignalProbe, Never>] = []
    var waitingCount: Int { pending.count }

    func probe() async -> UpdateSignalProbe {
        await withCheckedContinuation { pending.append($0) }
    }

    func finishFirst(fingerprint: String) {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume(returning: .init(result: .unchanged, fingerprint: fingerprint, entityTag: nil))
    }
}
