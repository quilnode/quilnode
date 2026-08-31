import Darwin
import Sparkle
import XCTest

@testable import QuilNodeApp

final class AppUpdateOutcomeTests: XCTestCase {
    func testNoUpdateIsCurrentOnlyWhenSparkleConfirmsTheVersion() {
        for reason in [SPUNoUpdateFoundReason.onLatestVersion, .onNewerThanLatestVersion] {
            XCTAssertEqual(AppUpdateOutcome.classify(noUpdate(reason)), .current)
        }
        for reason in [SPUNoUpdateFoundReason.unknown, .systemIsTooOld, .systemIsTooNew, .hardwareDoesNotSupportARM64] {
            guard case .unavailable = AppUpdateOutcome.classify(noUpdate(reason)) else {
                return XCTFail("Compatibility/unknown outcomes must not claim the app is current")
            }
        }
    }

    func testNormalCancellationAndAuthorizeLaterAreNotFailures() {
        for error in [
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled),
            sparkle(.installationCanceledError), sparkle(.installationAuthorizeLaterError),
        ] {
            XCTAssertEqual(AppUpdateOutcome.classify(error), .cancelled)
            XCTAssertEqual(AppUpdateOutcome.classify(sparkle(.downloadError, underlying: error)), .cancelled)
        }
    }

    func testEmptyFeedDoesNotProveTheAppIsCurrent() {
        let error = NSError(
            domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue),
            userInfo: [SPUNoUpdateFoundReasonKey: NSNumber(value: SPUNoUpdateFoundReason.onLatestVersion.rawValue)])
        guard case .unavailable = AppUpdateOutcome.classify(error) else {
            return XCTFail("An empty feed has no release version to compare")
        }
    }

    func testErrorDomainsMustMatchBeforeCodesAreInterpreted() {
        let error = NSError(domain: "fixture.unrelated", code: Int(SUError.noUpdateError.rawValue))
        guard case .failed = AppUpdateOutcome.classify(error) else {
            return XCTFail("An unrelated error domain cannot report success")
        }
    }

    func testOutOfSpaceIsFoundInsideFrameworkErrors() {
        for error in [
            NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError),
            NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)),
        ] {
            guard case .failed(let message) = AppUpdateOutcome.classify(sparkle(.fileCopyFailure, underlying: error))
            else {
                return XCTFail("Out of space must remain a failure")
            }
            XCTAssertTrue(message.contains("disk space"))
        }
    }

    func testNetworkLossIsActionableAndDoesNotClaimInstallation() {
        for code in [NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut] {
            let error = sparkle(.downloadError, underlying: NSError(domain: NSURLErrorDomain, code: code))
            guard case .failed(let message) = AppUpdateOutcome.classify(error) else {
                return XCTFail("Network loss must remain a failure")
            }
            XCTAssertTrue(message.contains("connection"))
        }
    }

    func testIntegrityAndInstallationFailuresNeverBecomeSuccess() {
        for code in [
            SUError.signatureError, .validationError, .downgradeError, .installationError,
            .installationWriteNoPermissionError, .authenticationFailure, .fileCopyFailure,
        ] {
            guard case .failed = AppUpdateOutcome.classify(sparkle(code)) else {
                return XCTFail("A rejected update cannot be presented as success")
            }
        }
    }

    func testWrappedTrustFailuresRetainTheRealCause() {
        for code in [SUError.signatureError, .validationError, .downgradeError] {
            XCTAssertEqual(
                AppUpdateOutcome.classify(sparkle(.installationError, underlying: sparkle(code))),
                AppUpdateOutcome.classify(sparkle(code)))
        }
        let cancelled = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        guard case .failed = AppUpdateOutcome.classify(sparkle(.validationError, underlying: cancelled)) else {
            return XCTFail("Cancellation must never hide a verification failure")
        }
    }

    func testPrivateFrameworkDescriptionsNeverReachTheDashboard() {
        let secretDescription = "fixture-private-location-and-download-token"
        let error = NSError(
            domain: "fixture.unknown", code: 9,
            userInfo: [NSLocalizedDescriptionKey: secretDescription])
        guard case .failed(let message) = AppUpdateOutcome.classify(error) else { return XCTFail() }
        XCTAssertFalse(message.contains(secretDescription))
    }

    private func noUpdate(_ reason: SPUNoUpdateFoundReason) -> NSError {
        NSError(
            domain: SUSparkleErrorDomain, code: Int(SUError.noUpdateError.rawValue),
            userInfo: [
                SPUNoUpdateFoundReasonKey: NSNumber(value: reason.rawValue),
                SPULatestAppcastItemFoundKey: SUAppcastItem.empty(),
            ])
    }

    private func sparkle(_ code: SUError, underlying: NSError? = nil) -> NSError {
        NSError(
            domain: SUSparkleErrorDomain, code: Int(code.rawValue),
            userInfo: underlying.map { [NSUnderlyingErrorKey: $0] } ?? [:])
    }
}
