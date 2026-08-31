import Darwin
import Foundation
import Sparkle

/// Interpret documented error domains/codes, never error-string fragments.
/// Raw framework errors can contain download URLs and private filesystem paths.
enum AppUpdateOutcome: Equatable {
    case current
    case unavailable(String)
    case cancelled
    case failed(String)

    static func classify(_ error: any Error) -> Self {
        let root = error as NSError
        if root.domain == SUSparkleErrorDomain, root.code == SUError.noUpdateError.rawValue {
            let reason = (root.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)?.intValue
            switch reason {
            case Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue),
                Int(SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue):
                // Sparkle also reports "latest" for an empty/app-inapplicable
                // feed. Require an actual comparison item before claiming it.
                guard root.userInfo[SPULatestAppcastItemFoundKey] is SUAppcastItem else {
                    return .unavailable("The signed feed has no application release available for this Mac.")
                }
                return .current
            case Int(SPUNoUpdateFoundReason.systemIsTooOld.rawValue):
                return .unavailable("The available release requires a newer macOS version.")
            case Int(SPUNoUpdateFoundReason.systemIsTooNew.rawValue):
                return .unavailable("The available release does not support this macOS version.")
            case Int(SPUNoUpdateFoundReason.hardwareDoesNotSupportARM64.rawValue):
                return .unavailable("The available release requires an Apple Silicon Mac.")
            default:
                return .unavailable("The signed feed contains no installable update for this Mac.")
            }
        }

        let errors = underlyingErrors(root)
        // Installer and feed errors wrap the actual validation/downgrade cause.
        // Preserve that cause instead of reporting a generic connection failure.
        let sparkleCodes = Set(errors.filter { $0.domain == SUSparkleErrorDomain }.map(\.code))
        if !sparkleCodes.isDisjoint(with: [Int(SUError.signatureError.rawValue), Int(SUError.validationError.rawValue)])
        {
            return .failed("The update could not be verified. Check again; do not bypass verification.")
        }
        if sparkleCodes.contains(Int(SUError.downgradeError.rawValue)) {
            return .failed("An older application build was rejected. Check for a newer release.")
        }
        if errors.contains(where: isCancellation) { return .cancelled }
        if errors.contains(where: {
            ($0.domain == NSCocoaErrorDomain && $0.code == NSFileWriteOutOfSpaceError)
                || ($0.domain == NSPOSIXErrorDomain && $0.code == Int(ENOSPC))
        }) {
            return .failed("There is not enough disk space. Free some space, then check for updates again.")
        }
        if errors.contains(where: { $0.domain == NSURLErrorDomain }) {
            return .failed("The update connection failed. Check your internet connection and try again.")
        }
        if root.domain == SUSparkleErrorDomain {
            switch root.code {
            case Int(SUError.installationWriteNoPermissionError.rawValue), Int(SUError.authenticationFailure.rawValue):
                return .failed("macOS could not authorize replacing the application. Try installing again.")
            case Int(SUError.downloadError.rawValue):
                return .failed("The app download did not complete. Check for updates to try again.")
            case Int(SUError.fileCopyFailure.rawValue), Int(SUError.installationError.rawValue):
                return .failed("The app installation did not complete. Reopen QuilNode and check for updates again.")
            default: break
            }
        }
        return .failed("The app update could not complete. Check for updates to try again.")
    }

    private static func isCancellation(_ error: NSError) -> Bool {
        (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == SUSparkleErrorDomain
                && [
                    Int(SUError.installationCanceledError.rawValue),
                    Int(SUError.installationAuthorizeLaterError.rawValue),
                ]
                .contains(error.code))
    }

    private static func underlyingErrors(_ root: NSError) -> [NSError] {
        var result: [NSError] = []
        var next: NSError? = root
        var seen: Set<ObjectIdentifier> = []
        while let error = next, result.count < 8, seen.insert(ObjectIdentifier(error)).inserted {
            result.append(error)
            next = error.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return result
    }
}
