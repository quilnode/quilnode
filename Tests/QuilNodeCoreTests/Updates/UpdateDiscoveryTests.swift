import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class UpdateDiscoveryTests: XCTestCase {
    func testReleaseDiscoveryAndUpdateModels() {
        let releaseManifest = """
            node-2.1.0.24-darwin-arm64
            node-2.1.0.24-darwin-arm64.dgst
            node-2.1.0.24-darwin-arm64.dgst.sig.1
            node-2.1.0.24-darwin-arm64.dgst.sig.2
            node-2.1.0.23-darwin-arm64
            """
        let officialRelease = ReleaseManifestParser.latest(in: releaseManifest)
        expect(officialRelease?.version == "2.1.0.24", "official release version parsing")
        expect(officialRelease?.signatureCount == 2, "official release signature counting")

        let qclientReleaseManifest = """
            qclient-2.1.0.22-darwin-arm64
            qclient-2.1.0.23-darwin-arm64
            qclient-2.1.0.23-darwin-arm64.dgst
            qclient-2.1.0.23-darwin-arm64.dgst.sig.17
            qclient-2.1.0.23-darwin-arm64.dgst.sig.1
            qclient-2.1.0.23-darwin-arm64.dgst.sig.1
            qclient-2.1.0.23-linux-amd64
            not-qclient-99.0.0-darwin-arm64
            """
        let qclientRelease = QClientReleaseManifestParser.latest(in: qclientReleaseManifest)
        expect(qclientRelease?.releaseVersion == "2.1.0.23", "qclient release version parsing")
        expect(qclientRelease?.binaryFileName == "qclient-2.1.0.23-darwin-arm64", "qclient artifact parsing")
        expect(qclientRelease?.digestPublished == true, "qclient digest discovery")
        expect(qclientRelease?.signatureIndices == [1, 17], "qclient signature indices are canonical and unique")
        expect(
            QClientRuntimeVersionParser.parse("initializing\n2.1.0-p22\n") == "2.1.0-p22",
            "qclient runtime version preserves its independent namespace"
        )
        expect(
            QClientRuntimeVersionParser.parse("qclient version: 2.1.0-p25\n") == "2.1.0-p25",
            "Rust qclient runtime version parsing"
        )
        expect(
            QClientRuntimeVersionParser.parse("2.1.0.23") == nil,
            "qclient runtime parser rejects a release filename version masquerading as runtime provenance"
        )
        let lfsPointer = GitLFSPointerParser.parse(
            """
            version https://git-lfs.github.com/spec/v1
            oid sha256:d753cfdba1dcd0b6341867e17ab4cd364b9eca6710f5fef621193c72ebe5a89b
            size 210578419
            """)
        expect(lfsPointer?.size == 210_578_419, "Git LFS pointer size parsing")
        expect(
            lfsPointer?.oid == "d753cfdba1dcd0b6341867e17ab4cd364b9eca6710f5fef621193c72ebe5a89b",
            "Git LFS pointer digest parsing"
        )
        expect(
            GitLFSPointerParser.parse("version https://git-lfs.github.com/spec/v1\noid sha256:bad\nsize 1") == nil,
            "Git LFS pointer rejects malformed object identifiers"
        )
        expect(LegacyPreferencesMigrator.isAllowed("walletOnboardingCompleted"), "legacy preference allowlist")
        expect(
            LegacyPreferencesMigrator.isAllowed("node-update-approved-marker-v2.1.0.25-number"),
            "legacy monotonic update marker prefix"
        )
        expect(
            LegacyPreferencesMigrator.isAllowed("node-update-signal-baseline-v1"),
            "validated update-signal baseline survives the bundle-ID migration"
        )
        expect(
            LegacyPreferencesMigrator.isAllowed("node-update-automatic-failure-candidate-v1"),
            "automatic retry suppression survives the bundle-ID migration"
        )
        expect(!LegacyPreferencesMigrator.isAllowed("privateKey"), "legacy preferences reject unclassified keys")

        expect(NodeVersion("v2.1.0.25")?.display == "2.1.0.25", "version prefix normalization")
        expect(NodeVersion("2.1.0.24")! < NodeVersion("2.1.0.25")!, "four-part version comparison")
        expect(NodeVersion("2.1.0")! < NodeVersion("2.1.0.1")!, "missing version component comparison")
        expect(NodeVersion("2.1.0.25.58")! > NodeVersion("2.1.0.25")!, "approved subpatch comparison")
        expect(
            QClientCompatibility.isCompatible(
                qclientReleaseVersion: "2.1.0.25", nodeVersion: "2.1.0.25.58"
            ),
            "qclient base protocol version remains compatible with a node subpatch"
        )
        expect(
            !QClientCompatibility.isCompatible(
                qclientReleaseVersion: "2.1.0.24", nodeVersion: "2.1.0.25.58"
            ),
            "qclient compatibility never crosses a protocol patch boundary"
        )
        expect(ApprovedDevelopmentMarker.parse("58\n") == 58, "approved development marker parsing")
        expect(ApprovedDevelopmentMarker.parse("58 # ready") == nil, "approval marker rejects extra syntax")
        expect(ApprovedDevelopmentMarker.parse("0") == nil, "approval marker rejects zero")
        expect(
            ApprovedDevelopmentMarker.version(baseVersion: "2.1.0.25", subpatch: 58) == "2.1.0.25.58",
            "approved development version composition"
        )

        let discoveryNow = Date(timeIntervalSince1970: 1_900_000_000)
        expect(
            !UpdateDiscoveryPolicy.shouldRefresh(
                lastCheckedAt: discoveryNow.addingTimeInterval(-299),
                now: discoveryNow
            ),
            "fresh update discovery is reused during navigation"
        )
        expect(
            UpdateDiscoveryPolicy.shouldRefresh(
                lastCheckedAt: discoveryNow.addingTimeInterval(-300),
                now: discoveryNow
            ),
            "stale update discovery refreshes at the policy boundary"
        )
        expect(
            UpdateDiscoveryPolicy.nextSignalDelay(consecutiveFailures: 0, jitterUnit: 0) == 5 * 60,
            "successful update signals return to the five-minute cadence"
        )
        expect(
            UpdateDiscoveryPolicy.nextSignalDelay(consecutiveFailures: 2, jitterUnit: 0) == 20 * 60,
            "signal failures back off exponentially"
        )
        expect(
            UpdateDiscoveryPolicy.nextSignalDelay(consecutiveFailures: 9, jitterUnit: 1) == 66 * 60,
            "signal backoff is capped before bounded jitter"
        )
        let protocolPlan = ProtocolSourcePlan.paths(
            previous: ["crates/quil-execution/src/known.rs", "../private.rs"],
            recentlyChanged: [
                "crates/quil-types/src/new.rs",
                "crates/quil-types/src/new.rs",
                "node/secrets.rs",
                "crates/quil-types/../../escape.rs",
            ],
            required: ["crates/quil-execution/src/global_intrinsic/materialize.rs"]
        )
        expect(
            protocolPlan == [
                "crates/quil-execution/src/global_intrinsic/materialize.rs",
                "crates/quil-execution/src/known.rs",
                "crates/quil-types/src/new.rs",
            ],
            "protocol sparse plan is ordered, unique, and traversal-safe"
        )
        expect(
            ProtocolSourcePlan.paths(
                previous: [],
                recentlyChanged: (0..<10).map { "crates/example/\($0).rs" },
                required: [],
                maximumPathCount: 3
            ).count == 3,
            "protocol sparse plan enforces its resource bound"
        )

        let sourceBuild = InstalledNodeBuildParser.parse(
            symlinkTarget: "/opt/quilibrium/node/node-2.1.0.25-source-0d9f2d2-darwin-arm64"
        )
        expect(sourceBuild.kind == .source, "source build classification")
        expect(sourceBuild.version == "2.1.0.25", "source build version parsing")
        expect(sourceBuild.commit == "0d9f2d2", "source build commit parsing")
        let approvedSourceBuild = InstalledNodeBuildParser.parse(
            symlinkTarget: "/opt/quilibrium/node/node-2.1.0.25.58-source-13720830-darwin-arm64"
        )
        expect(approvedSourceBuild.version == "2.1.0.25.58", "approved subpatch build parsing")
        expect(approvedSourceBuild.commit == "13720830", "approved subpatch commit parsing")
        let signedBuild = InstalledNodeBuildParser.parse(
            symlinkTarget: "node-2.1.0.24-darwin-arm64"
        )
        expect(signedBuild.kind == .signed, "signed build classification")

        let branchOutput = """
            1787822060\tv2.1.0.25\t5a357ebf07a00d213fdc2e492f2fc17ddc0642a1\tresolve prover grid quirks
            1787825660\tfix/hot-path\t62b60eeabf3dee7a992c33b0a248d2df9ba9fc73\tnewest feature branch
            1780220000\tv2.1.0.24\tf7753c3aef54c83e08b7a40ebc55a4479dfb158f\tstable work
            """
        let branchHeads = GitBranchHeadParser.parse(branchOutput)
        expect(branchHeads.count == 3, "branch head parsing")
        expect(
            GitBranchHeadParser.newestAnyBranch(in: branchHeads)?.name == "fix/hot-path", "newest any-branch selection")
        expect(
            GitBranchHeadParser.newestVersionBranch(in: branchHeads)?.name == "v2.1.0.25",
            "highest version-branch selection")
        expect(branchHeads[1].subject == "newest feature branch", "branch subject parsing")

        let activation = UpdateActivationManifest(
            channel: "source",
            version: "2.1.0.25",
            branch: "fix/hot-path",
            commit: "62b60eeabf3dee7a992c33b0a248d2df9ba9fc73",
            binaryFileName: "node-2.1.0.25-source-62b60eea-darwin-arm64",
            sha256: String(repeating: "a", count: 64)
        )
        expect(
            (try? JSONDecoder().decode(UpdateActivationManifest.self, from: JSONEncoder().encode(activation)))
                == activation, "activation manifest round trip")

        let qclientArtifact = SignedArtifactActivation(
            kind: .qclient,
            releaseVersion: "2.1.0.23",
            reportedVersion: "2.1.0-p22",
            binaryFileName: "qclient-2.1.0.23-darwin-arm64",
            sha256: String(repeating: "b", count: 64),
            signatureIndices: [1, 2, 8, 11, 13, 14, 17]
        )
        let sourceQClientArtifact = SignedArtifactActivation(
            kind: .qclient,
            trust: .pinnedSource,
            releaseVersion: "2.1.0.25",
            reportedVersion: "2.1.0-p25",
            binaryFileName: "qclient-2.1.0.25-source-13720830-darwin-arm64",
            sha256: String(repeating: "c", count: 64),
            signatureIndices: [],
            branch: "v2.1.0.25",
            commit: "13720830c4d99f5c5e9d55ab1eedf005b8b96ccf"
        )
        expect(
            (try? JSONDecoder().decode(
                SignedArtifactActivation.self,
                from: JSONEncoder().encode(sourceQClientArtifact)
            )) == sourceQClientArtifact,
            "pinned source qclient provenance round trip"
        )
        let firstInstallManifest = FirstInstallActivationManifest(
            node: SignedArtifactActivation(
                kind: .node,
                releaseVersion: "2.1.0.24",
                reportedVersion: "2.1.0.24",
                binaryFileName: "node-2.1.0.24-darwin-arm64",
                sha256: String(repeating: "a", count: 64),
                signatureIndices: [1, 2, 8, 11, 13, 14, 17]
            ),
            qclient: qclientArtifact
        )
        expect(
            (try? JSONDecoder().decode(
                FirstInstallActivationManifest.self,
                from: JSONEncoder().encode(firstInstallManifest)
            )) == firstInstallManifest,
            "typed first-install node and qclient manifest round trip"
        )

        var snapshot = NodeSnapshot(isRunning: true, pendingJoins: 3, logLastModifiedAt: Date())
        expect(snapshot.health == .joining, "joining health state")
        snapshot.pendingJoins = 0
        snapshot.activeShards = 3
        expect(snapshot.health == .active, "active health state")
        snapshot.isRunning = false
        expect(snapshot.health == .stopped, "stopped health state")

        snapshot = NodeSnapshot(
            isRunning: true,
            frame: 500_004,
            frameLastAdvancedAt: Date().addingTimeInterval(-6 * 60)
        )
        expect(snapshot.health == .stalled, "stalled frame state")

        let warningsLog = (0..<10).map {
            "2030-01-02T03:04:\($0)Z\twarn\tfile.rs:1\twarning \($0)\t{\"n\":\($0)}"
        }.joined(separator: "\n")
        let warnings = NodeStatusParser.recentWarnings(in: warningsLog, limit: 3)
        expect(warnings.count == 3, "warning result bound")
        expect(warnings.last?.contains("warning 9") == true, "latest warning selection")

        expect(ProcessCPUTimeParser.parse("304:29.81") == 18_269.81, "process CPU minute parsing")
        expect(ProcessCPUTimeParser.parse("02:04:29.50") == 7_469.5, "process CPU hour parsing")
        expect(ProcessCPUTimeParser.parse("1-02:04:29.50") == 93_869.5, "process CPU day parsing")
        expect(ProcessCPUTimeParser.parse("bad") == nil, "invalid process CPU time rejection")

    }
}
