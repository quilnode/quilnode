import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class IdentityPresentationTests: XCTestCase {
    func testPublicRolesRemainDistinctAndPrivacyClassified() {
        let observedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let presentation = IdentityWorkspacePresentation.make(
            snapshot: NodeSnapshot(
                collectedAt: observedAt,
                isRunning: true,
                peerID: "QmNetworkPeer",
                legacyPeerID: "QmSeniorityRoot",
                proverAddress: "0xProver",
                quilBalance: "42.5",
                quilAccount: "0xAccount",
                balanceUpdatedAt: observedAt,
                seniority: 13_219_200,
                seniorityUpdatedAt: observedAt,
                seniorityEvidenceSource: .consensusRegistry,
                seniorityEvidenceKind: .registrySnapshot,
                metricsUpdatedAt: observedAt
            ),
            seniorityTrend: collectingTrend
        )

        XCTAssertEqual(presentation.roles.map(\.kind), IdentityRole.allCases)
        XCTAssertEqual(presentation.role(.networkPeer).value, "QmNetworkPeer")
        XCTAssertEqual(presentation.role(.seniority).value, "QmSeniorityRoot")
        XCTAssertEqual(presentation.role(.prover).value, "0xProver")
        XCTAssertEqual(presentation.role(.quilAccount).value, "0xAccount")
        XCTAssertTrue(presentation.roles.allSatisfy { $0.privacyField == .networkIdentifier })
        XCTAssertEqual(presentation.chainEvidenceSource, "Chain registry")
    }

    func testParticipationDoesNotClaimRewardsOrEligibility() {
        let presentation = IdentityWorkspacePresentation.make(
            snapshot: NodeSnapshot(isRunning: true, peers: 18),
            seniorityTrend: collectingTrend
        )

        XCTAssertEqual(presentation.participation.state, .awaitingAllocation)
        XCTAssertEqual(presentation.participation.title, "Awaiting allocation")
        XCTAssertFalse(presentation.participation.detail.localizedCaseInsensitiveContains("eligible"))
        XCTAssertFalse(presentation.participation.detail.localizedCaseInsensitiveContains("earning"))
    }

    func testActiveAllocationDoesNotClaimContinuousProofProductionOrReward() {
        let presentation = IdentityWorkspacePresentation.make(
            snapshot: NodeSnapshot(
                isRunning: true,
                activeShards: 5,
                totalAllocations: 7
            ),
            seniorityTrend: collectingTrend
        )

        XCTAssertEqual(presentation.participation.title, "Allocations active")
        XCTAssertFalse(presentation.participation.detail.localizedCaseInsensitiveContains("serving"))
        XCTAssertFalse(presentation.participation.detail.localizedCaseInsensitiveContains("reward"))
        XCTAssertTrue(presentation.participation.detail.localizedCaseInsensitiveContains("not continuous"))
    }

    func testMissingIdentifiersStayUnavailableAndUnclassified() {
        let presentation = IdentityWorkspacePresentation.make(
            snapshot: .empty,
            seniorityTrend: collectingTrend
        )

        XCTAssertTrue(presentation.roles.allSatisfy { !$0.isAvailable })
        XCTAssertTrue(presentation.roles.allSatisfy { $0.privacyField == nil })
        XCTAssertTrue(presentation.roles.allSatisfy { $0.displayedValue == "Not available" })
    }

    func testBalanceFormatterKeepsSummaryLegible() {
        XCTAssertEqual(IdentityBalanceFormatter.compact("42.500000"), "42.5")
        XCTAssertEqual(IdentityBalanceFormatter.compact("0.000000001250000000"), "1.250e-09")
        XCTAssertEqual(IdentityBalanceFormatter.compact("0.000000000000"), "0")
    }

    private var collectingTrend: SeniorityTrend {
        SeniorityTrend(
            direction: .collecting,
            delta: 0,
            comparisonStartedAt: nil,
            latestObservedAt: nil
        )
    }
}
