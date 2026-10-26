import Foundation
import QuilNodeShared
import XCTest

@testable import QuilNodeCore

final class ModernQClientBalanceTests: XCTestCase {
    func testThreeComponentsRemainSeparateAndExact() throws {
        let balance = try XCTUnwrap(
            QuilBalanceParser.parse(
                """
                Claimable prover rewards: 2.250000000125 QUIL (witness cites global frame 712; requires minting)
                Unshielded legacy coins: 12000000000 base units across 2 coins (3 already shielded)
                Confidential coins: 8000000001 base units across 1 coins reported unspent by the configured node (not a finalized balance)
                """))
        XCTAssertEqual(balance.amount, "1.000000000125")
        XCTAssertEqual(balance.confidential?.coinCount, 1)
        XCTAssertEqual(balance.legacy?.amount, "1.5")
        XCTAssertEqual(balance.rewards?.amount, "2.250000000125")
        XCTAssertEqual(balance.rewards?.frame, 712)
        XCTAssertNil(balance.account)
        XCTAssertTrue(balance.isComplete)
    }

    func testMissingRewardWitnessDoesNotBecomeZero() throws {
        let balance = try XCTUnwrap(
            QuilBalanceParser.parse(
                """
                Claimable prover rewards: unavailable (no claimable reward witness returned)
                Unshielded legacy coins: none (this node has no Ed448 identity)
                Confidential QUIL coins: none exist on the network yet (no QUIL root published)
                """))
        XCTAssertNil(balance.rewards?.amount)
        XCTAssertEqual(balance.rewards?.state, .unavailable)
        XCTAssertEqual(balance.legacy?.state, .notApplicable)
        XCTAssertEqual(balance.confidential?.state, .noRoot)
        XCTAssertEqual(balance.amount, "0")
        XCTAssertFalse(balance.isComplete)
    }

    func testFailedOrTimedOutReadRetainsRewardEvidence() throws {
        for timedOut in [false, true] {
            let read = PrivilegedServiceClient.parseBalanceResponse(
                PrivilegedServiceResponse(
                    success: true, message: "partial",
                    balanceOutput: """
                        Claimable prover rewards: 42.000000000000 QUIL (witness cites global frame 900; requires minting)
                        Confidential coins: unavailable (no serving peer answered)
                        Error: balance incomplete: confidential coins unavailable
                        """,
                    balanceExitCode: 1, balanceTimedOut: timedOut
                ))
            XCTAssertEqual(read.balance?.rewards?.amount, "42.000000000000")
            XCTAssertNil(read.balance?.amount)
            XCTAssertNotNil(read.error)
        }
    }

    func testEarlierRustOutputAndLegacyOutputStillWork() {
        XCTAssertEqual(
            QuilBalanceParser.parse(
                """
                8000000000 base units across 1 coins reported unspent by the configured node (not a finalized balance)
                """)?.amount, "1")
        XCTAssertEqual(QuilBalanceParser.parse("Total balance: 12.50 QUIL (Account 0x1234)")?.amount, "12.50")
        XCTAssertNil(QuilBalanceParser.parse("Total balance: NaN QUIL (Account 0x1234)"))
    }

    func testFullU128PrecisionAndMalformedAmounts() {
        XCTAssertEqual(QuilBalanceParser.quilFromBaseUnits("1"), "0.000000000125")
        XCTAssertEqual(QuilBalanceParser.quilFromBaseUnits("0"), "0")
        XCTAssertEqual(
            QuilBalanceParser.quilFromBaseUnits("340282366920938463463374607431768211455"),
            "42535295865117307932921825928.971026431875"
        )
        for invalid in ["-1", "NaN", "1e9", "", "340282366920938463463374607431768211456"] {
            XCTAssertNil(QuilBalanceParser.quilFromBaseUnits(invalid))
        }
    }

    func testModernWorkerCapacityDoesNotEraseRunningWorkers() throws {
        let status = try XCTUnwrap(
            ProverStatusParser.parse(
                """
                Seniority: 123
                Running Workers: 9 of 6 configured | draining 3
                Core 9: Filter: aabb Storage: 2 GB / 5 GB  Draining: above the configured count; stops once its seat departs
                """))
        XCTAssertEqual(status.runningWorkers, 9)
        XCTAssertEqual(status.workers.first?.totalStorage, "5 GB")
    }
}
