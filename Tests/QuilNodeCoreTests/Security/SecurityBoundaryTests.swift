import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class SecurityBoundaryTests: XCTestCase {
    func testSourceSandboxReleasePolicyAndMalformedInputs() {
        let sandboxLayout = SourceBuildSandbox.Layout(
            workspace: URL(fileURLWithPath: "/private/tmp/quilnode-security-test/workspace"),
            repository: URL(fileURLWithPath: "/private/tmp/quilnode-security-test/workspace/repo"),
            cargoHome: URL(fileURLWithPath: "/private/tmp/quilnode-security-test/workspace/cargo"),
            isolatedHome: URL(fileURLWithPath: "/private/tmp/quilnode-security-test/workspace/home"),
            temporaryDirectory: URL(fileURLWithPath: "/private/tmp/quilnode-security-test/workspace/tmp"),
            rustupHome: URL(fileURLWithPath: "/Users/example/.rustup"),
            cargoBin: URL(fileURLWithPath: "/Users/example/.cargo/bin"),
            flintDirectory: URL(fileURLWithPath: "/Users/example/.local/share/QuilNode/Toolchains/flint-3.6.0")
        )
        if let compilePolicy = try? SourceBuildSandbox.profile(
            layout: sandboxLayout,
            allowsNetwork: false
        ),
            let fetchPolicy = try? SourceBuildSandbox.profile(
                layout: sandboxLayout,
                allowsNetwork: true
            )
        {
            expect(compilePolicy.contains("(deny default)"), "source sandbox is deny-by-default")
            expect(compilePolicy.contains("(deny network*)"), "source compilation denies networking")
            expect(fetchPolicy.contains("(allow network-outbound)"), "dependency fetch has a distinct network phase")
            expect(
                !compilePolicy.contains("/Users/example/Documents"), "source sandbox does not expose the operator home")
            let environment = try? SourceBuildSandbox.environment(layout: sandboxLayout)
            expect(
                environment?["HOME"]?.contains("quilnode-security-test") == true,
                "source build receives an isolated HOME")
            expect(
                environment?["CARGO_HOME"]?.contains("quilnode-security-test") == true,
                "source build receives an isolated Cargo home")
        } else {
            XCTFail("source sandbox policy generation")
        }
        expect(
            (try? SourceBuildSandbox.arguments(
                profileURL: URL(fileURLWithPath: "/private/tmp/policy.sb"),
                executable: "bin/bash",
                arguments: []
            )) == nil,
            "source sandbox rejects relative executables"
        )

        do {
            let fm = FileManager.default
            // Use the canonical /private/tmp path. FileManager's temporaryDirectory is
            // presented through /var on macOS, and sandbox profiles intentionally use
            // canonical paths to avoid alias-based policy confusion.
            let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true).appendingPathComponent(
                "quilnode-sandbox-test-\(UUID().uuidString)",
                isDirectory: true
            )
            let workspace = root.appendingPathComponent("workspace", isDirectory: true)
            let repository = workspace.appendingPathComponent("repo", isDirectory: true)
            let cargoHome = workspace.appendingPathComponent("cargo", isDirectory: true)
            let isolatedHome = workspace.appendingPathComponent("home", isDirectory: true)
            let temporary = workspace.appendingPathComponent("tmp", isDirectory: true)
            let deniedSecret = root.appendingPathComponent("outside-secret")
            let allowedOutput = workspace.appendingPathComponent("sandbox-output")
            for directory in [repository, cargoHome, isolatedHome, temporary] {
                try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            try Data("must remain unreadable".utf8).write(to: deniedSecret)
            let liveLayout = SourceBuildSandbox.Layout(
                workspace: workspace,
                repository: repository,
                cargoHome: cargoHome,
                isolatedHome: isolatedHome,
                temporaryDirectory: temporary,
                rustupHome: URL(fileURLWithPath: "/Users/example/.rustup"),
                cargoBin: URL(fileURLWithPath: "/Users/example/.cargo/bin"),
                flintDirectory: URL(fileURLWithPath: "/Users/example/.local/share/QuilNode/Toolchains/flint-3.6.0")
            )
            let policyURL = workspace.appendingPathComponent("policy.sb")
            let livePolicy = try SourceBuildSandbox.profile(layout: liveLayout, allowsNetwork: false)
            try Data(livePolicy.utf8).write(to: policyURL)
            let process = Process()
            let sandboxError = Pipe()
            process.executableURL = URL(fileURLWithPath: SourceBuildSandbox.executable)
            process.arguments = try SourceBuildSandbox.arguments(
                profileURL: policyURL,
                executable: "/bin/sh",
                arguments: [
                    "-c",
                    "if test -r \"$1\"; then exit 9; fi; printf ok > \"$2\"",
                    "quilnode-sandbox-test",
                    deniedSecret.path,
                    allowedOutput.path,
                ]
            )
            // A sandboxed process must start inside an allowed tree. Production source
            // builds always run from their private workspace; mirror that boundary here
            // instead of inheriting the test runner's repository working directory.
            process.currentDirectoryURL = workspace
            process.environment = try SourceBuildSandbox.environment(layout: liveLayout)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = sandboxError
            try process.run()
            process.waitUntilExit()
            let sandboxErrorText = String(
                decoding: sandboxError.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            expect(
                process.terminationStatus == 0,
                "macOS applies the source sandbox policy\(sandboxErrorText.isEmpty ? "" : ": \(sandboxErrorText)")"
            )
            expect(
                (try? String(contentsOf: allowedOutput, encoding: .utf8)) == "ok",
                "source sandbox permits only controlled output")
            try? fm.removeItem(at: root)
        } catch {
            XCTFail("live source sandbox enforcement: \(error.localizedDescription)")
        }

        expect(ReleaseTrustPolicy.minimumSignatures == 7, "release quorum policy")
        expect(ReleaseTrustPolicy.signatories.count == 17, "release signer policy")
        expect(
            ReleaseTrustPolicy.signatories.allSatisfy {
                $0.count == 114 && $0.allSatisfy(\.isHexDigit)
            },
            "Ed448 release keys are canonical 57-byte hex values"
        )

        // Deterministic malformed-input corpus for every parser that consumes node,
        // release, log, or subprocess text. This is not a proof of memory safety, but
        // it permanently exercises mixed UTF-8, controls, delimiters, large numeric
        // fields, and truncated structured data under Swift's runtime checks.
        var parserFuzzState: UInt64 = 0x51A7_C0DE_D15C_A11D
        for iteration in 0..<1_500 {
            let length = (iteration * 73) % 2_048
            var bytes = [UInt8]()
            bytes.reserveCapacity(length)
            for _ in 0..<length {
                parserFuzzState = parserFuzzState &* 6_364_136_223_846_793_005 &+ 1
                bytes.append(UInt8(truncatingIfNeeded: parserFuzzState >> 24))
            }
            let malformed = String(decoding: bytes, as: UTF8.self)
            _ = NodeStatusParser.latestStatus(in: malformed)
            _ = NodeInfoParser.parse(malformed)
            _ = NodeMetricsParser.value("metric", in: malformed)
            _ = WorkerRuntimeParser.localThreadWorkerCount(in: malformed)
            _ = QuilBalanceParser.parse(malformed)
            _ = ProverStatusParser.parse(malformed)
            _ = LocalRegistryParser.parse(malformed)
            _ = ProcessCPUTimeParser.parse(malformed)
            _ = GitLFSPointerParser.parse(malformed)
            _ = ApprovedDevelopmentMarker.parse(malformed)
            _ = GitBranchHeadParser.parse(malformed)
            _ = ReleaseManifestParser.latest(in: malformed)
            _ = QClientReleaseManifestParser.latest(in: malformed)
            _ = QClientRuntimeVersionParser.parse(malformed)
            _ = ChainProgressLogParser.parse(malformed, now: Date(timeIntervalSince1970: 2_000_000_000))
        }
        expect(true, "malformed parser corpus completes without a trap")

    }
}
