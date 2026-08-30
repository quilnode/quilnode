import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class ProtocolMilestoneTests: XCTestCase {
    func testMilestoneDetectionTimingAndPresentation() {
        let milestoneSource = ProtocolSourceFile(
            path: "crates/quil-execution/src/global_intrinsic/materialize.rs",
            contents: """
                /// Coordinated QUIL prover-tree RESET v4 — complete tree reset after archive divergence.
                /// Automatic workers clear stale bindings and rejoin the clean grid.
                pub const QUIL_PROVER_RESET_V4_FRAME: u64 = 754_000;
                """
        )
        let milestoneReferences = ProtocolSourceFile(
            path: "crates/quil-engine/src/frame_materializer.rs",
            contents: """
                // Prover-reset v4 (mainnet 755_000): re-baseline once more.
                if frame_number == quil_prover_reset_v4_frame() {}
                """
        )
        let ignoredTestMilestone = ProtocolSourceFile(
            path: "crates/quil-execution/tests/reset_test.rs",
            contents: "pub const FAKE_PROVER_RESET_V9_FRAME: u64 = 999_000;"
        )
        let milestones = ProtocolMilestoneDetector.detect(
            files: [milestoneSource, milestoneReferences, ignoredTestMilestone],
            branch: "v2.1.0.25",
            commit: String(repeating: "a", count: 40),
            committedAt: Date(timeIntervalSince1970: 1_787_900_000),
            checkedAt: Date(timeIntervalSince1970: 1_787_900_100)
        )
        expect(milestones.count == 1, "production milestone discovery excludes tests")
        expect(milestones.first?.symbol == "QUIL_PROVER_RESET_V4_FRAME", "milestone symbol parsing")
        expect(milestones.first?.targetFrame == 754_000, "underscore frame parsing")
        expect(milestones.first?.title == "QUIL Prover Reset V4", "milestone title formatting")
        expect(milestones.first?.conflictingFrames.isEmpty == true, "comments are not executable conflicts")
        expect(milestones.first?.documentationFrames == [755_000], "differing comment retained as provenance")
        expect(milestones.first?.sourceAssessment == .documentationNote, "documentation note source assessment")

        let conflictingExecutable = ProtocolSourceFile(
            path: "crates/quil-node/src/conflicting_schedule.rs",
            contents: "pub const QUIL_PROVER_RESET_V4_FRAME: u64 = 756_000;"
        )
        let executableConflict = ProtocolMilestoneDetector.detect(
            files: [milestoneSource, conflictingExecutable],
            branch: "v2.1.0.25",
            commit: String(repeating: "b", count: 40),
            committedAt: Date(timeIntervalSince1970: 1_787_900_000)
        ).first
        let executableFrames = Set(
            ([executableConflict?.targetFrame].compactMap { $0 }) + (executableConflict?.conflictingFrames ?? []))
        expect(executableFrames == Set([754_000, 756_000]), "different executable definitions are preserved")
        expect(executableConflict?.sourceAssessment == .executableConflict, "executable conflict source assessment")

        let localTiming = ProtocolMilestoneTiming.estimate(
            targetFrame: 754_000,
            currentFrame: 753_400,
            framesPerMinute: 6,
            lowerFramesPerMinute: 5,
            upperFramesPerMinute: 7,
            now: Date(timeIntervalSince1970: 0)
        )
        expect(localTiming.framesRemaining == 600, "milestone frames remaining")
        expect(localTiming.basis == .observed, "milestone observed ETA basis")
        expect(localTiming.expectedAt == Date(timeIntervalSince1970: 6_000), "milestone center ETA")
        expect(localTiming.earliestAt == Date(timeIntervalSince1970: 600.0 / 7.0 * 60), "milestone earliest ETA")
        expect(localTiming.latestAt == Date(timeIntervalSince1970: 7_200), "milestone latest ETA")
        let nominalTiming = ProtocolMilestoneTiming.estimate(
            targetFrame: 100,
            currentFrame: 94,
            framesPerMinute: nil,
            now: Date(timeIntervalSince1970: 0)
        )
        expect(nominalTiming.basis == .nominal, "milestone nominal fallback")
        expect(nominalTiming.expectedAt == Date(timeIntervalSince1970: 60), "ten-second nominal frame pace")
        expect(
            ProtocolMilestonePhase.resolve(targetFrame: 754_000, currentFrame: 753_500) == .imminent,
            "milestone imminent phase")
        expect(
            ProtocolMilestonePhase.resolve(targetFrame: 754_000, currentFrame: 754_000) == .reached,
            "milestone reached phase")
        if let milestone = milestones.first {
            let eventID = ProtocolMilestonePresentationPolicy.eventID(for: milestone)
            expect(
                ProtocolMilestonePresentationPolicy.overviewSelection(
                    from: [milestone],
                    currentFrame: 753_000
                )?.milestone == milestone,
                "upcoming milestone appears on Overview"
            )
            expect(
                ProtocolMilestonePresentationPolicy.overviewSelection(
                    from: [milestone],
                    currentFrame: 753_000,
                    dismissedEventIDs: [eventID]
                ) == nil,
                "acknowledged milestone leaves Overview"
            )
            expect(
                ProtocolMilestonePresentationPolicy.overviewSelection(
                    from: [milestone],
                    currentFrame: 754_500
                )?.state == .passedWithoutLocalEvidence,
                "recently passed milestone remains briefly visible"
            )
            expect(
                ProtocolMilestonePresentationPolicy.overviewSelection(
                    from: [milestone],
                    currentFrame: 754_721
                ) == nil,
                "completed milestone expires from Overview after one epoch"
            )
            expect(
                ProtocolMilestonePresentationPolicy.overviewSelection(
                    from: [milestone],
                    currentFrame: 754_100,
                    observedMilestones: [milestone.symbol: milestone.targetFrame]
                )?.state == .passedLocallyObserved,
                "local success evidence classifies a passed milestone"
            )

            var changedTarget = milestone
            changedTarget.targetFrame += 1
            expect(
                ProtocolMilestonePresentationPolicy.eventID(for: changedTarget) != eventID,
                "changed target creates a fresh presentation event"
            )

            var requiredUpdate = milestone
            requiredUpdate.installedSupport = .missing
            expect(
                ProtocolMilestonePresentationPolicy.overviewSelection(
                    from: [requiredUpdate],
                    currentFrame: 760_000,
                    dismissedEventIDs: [ProtocolMilestonePresentationPolicy.eventID(for: requiredUpdate)]
                )?.isDismissible == false,
                "unresolved update requirement cannot be hidden"
            )
        }
        let resetLog = #"2026-08-28T18:00:00Z info prover-reset v4: prover-tree wiped + rebuilt {"frame":754000}"#
        expect(
            ProtocolEventLogParser.observations(in: resetLog)["QUIL_PROVER_RESET_V4_FRAME"] == 754_000,
            "successful protocol reset observation"
        )
        expect(
            ProtocolEventLogParser.observations(in: "prover-reset v4: prover-tree reset FAILED {\"frame\":754000}")
                .isEmpty,
            "failed reset is not successful evidence"
        )

    }
}
