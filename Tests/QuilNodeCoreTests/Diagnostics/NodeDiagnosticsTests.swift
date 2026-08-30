import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class NodeDiagnosticsTests: XCTestCase {
    func testDiagnosticHealthAndArchiveRecoveryClassification() {
        let diagnosticNow = Date(timeIntervalSince1970: 2_100_000_000)
        let diagnosticTimestamp = diagnosticNow.ISO8601Format()
        let archiveRecoveryLog = """
            \(diagnosticTimestamp)\tinfo\tquil_rpc/src/frame_sync.rs:580\tarchive poller connected\t{"addr":"redacted:8340","coreId":0}
            \(diagnosticTimestamp)\tinfo\tquil_rpc/src/frame_sync.rs:645\tarchive poller: not advancing — current endpoint is not ahead of us\t{"endpoint_head":758358,"local_frame":758358}
            \(diagnosticTimestamp)\tinfo\tquil_rpc/src/frame_sync.rs:645\tarchive poller: not advancing — current endpoint is not ahead of us\t{"endpoint_head":758358,"local_frame":758358}
            \(diagnosticTimestamp)\twarn\tquil_node/master_node/archive_sync.rs:2856\tshard_info refresh failed (will retry)\t{"error":"all archive endpoints failed; last error: endpoint returned only zero shard sizes"}
            \(diagnosticTimestamp)\twarn\tquil_node/master_node/archive_sync.rs:2856\tshard_info refresh failed (will retry)\t{"error":"all archive endpoints failed; last error: endpoint returned only zero shard sizes"}
            \(diagnosticTimestamp)\twarn\tquil_node/master_node/archive_sync.rs:2856\tshard_info refresh failed (will retry)\t{"error":"all archive endpoints failed; last error: endpoint returned only zero shard sizes"}
            """
        let parsedRecoveryEvidence = ChainProgressLogParser.parse(archiveRecoveryLog, now: diagnosticNow)
        expect(
            parsedRecoveryEvidence?.archiveConnections == 1, "archive recovery parser counts live archive connections")
        expect(
            parsedRecoveryEvidence?.archiveAtLocalHead == 2,
            "archive recovery parser recognizes equal archive and local heads")
        expect(
            parsedRecoveryEvidence?.zeroShardSizeResponses == 3,
            "archive recovery parser recognizes state convergence retries")
        expect(
            ChainProgressLogParser.parse(archiveRecoveryLog, now: diagnosticNow.addingTimeInterval(181)) == nil,
            "archive recovery parser expires old evidence"
        )
        let readyFirewall = ManagedFirewallStatus(
            globalEnabled: true,
            blockAllEnabled: false,
            stealthEnabled: true,
            nodeRule: .allowed,
            managedByQuilNode: true,
            verifiedAt: diagnosticNow
        )
        let diagnosticInspection = NetworkLocalInspection(
            observedAt: diagnosticNow,
            tcpListeners: [8_336, 8_340],
            inboundPeerSockets: 1,
            inspectionSucceeded: true
        )
        let diagnosticNetwork = NetworkReadinessAssessment(
            state: .inboundVerified,
            title: "Inbound peer traffic verified",
            detail: "Local evidence confirms inbound traffic."
        )
        let checkingReport = NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: .empty,
                initialRefreshComplete: false,
                serviceAvailable: nil,
                networkAssessment: .init(state: .inspecting, title: "Inspecting", detail: "Checking"),
                networkInspection: .empty,
                firewall: nil,
                qclientReady: nil,
                qclientCompatible: nil,
                now: diagnosticNow
            )
        )
        expect(
            checkingReport.checks.first(where: { $0.id == "process" })?.state == .checking,
            "diagnostics never labels unprobed startup as stopped"
        )

        let healthyDiagnosticSnapshot = NodeSnapshot(
            collectedAt: diagnosticNow,
            isRunning: true,
            processID: 42,
            version: "2.1.0.25",
            frame: 754_100,
            peers: 20,
            inboundConnectionsEstablished: 1,
            processUptime: "01:00:00",
            logLastModifiedAt: diagnosticNow.addingTimeInterval(-10),
            metricsUpdatedAt: diagnosticNow.addingTimeInterval(-5),
            frameLastAdvancedAt: diagnosticNow.addingTimeInterval(-20),
            framesPerMinute: 6
        )
        let healthyReport = NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: healthyDiagnosticSnapshot,
                initialRefreshComplete: true,
                serviceAvailable: true,
                networkAssessment: diagnosticNetwork,
                networkInspection: diagnosticInspection,
                firewall: readyFirewall,
                qclientReady: true,
                qclientCompatible: true,
                now: diagnosticNow
            )
        )
        expect(healthyReport.overallState == .passed, "healthy diagnostic report")

        var stalledDiagnosticSnapshot = healthyDiagnosticSnapshot
        stalledDiagnosticSnapshot.frameLastAdvancedAt = diagnosticNow.addingTimeInterval(-1_300)
        let stalledReport = NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: stalledDiagnosticSnapshot,
                initialRefreshComplete: true,
                serviceAvailable: true,
                networkAssessment: diagnosticNetwork,
                networkInspection: diagnosticInspection,
                firewall: readyFirewall,
                qclientReady: true,
                qclientCompatible: true,
                now: diagnosticNow
            )
        )
        expect(
            stalledReport.checks.first(where: { $0.id == "frame-progress" })?.state == .advisory,
            "diagnostics flag unresolved progress without guessing at a destructive repair"
        )
        expect(
            stalledReport.checks.first(where: { $0.id == "frame-progress" })?.repair == .refreshEvidence,
            "unresolved progress refreshes evidence instead of blindly restarting"
        )

        var recoveryDiagnosticSnapshot = healthyDiagnosticSnapshot
        recoveryDiagnosticSnapshot.frame = 758_358
        recoveryDiagnosticSnapshot.archivePeers = 3
        recoveryDiagnosticSnapshot.frameLastAdvancedAt = diagnosticNow.addingTimeInterval(-900)
        recoveryDiagnosticSnapshot.chainProgressEvidence = parsedRecoveryEvidence
        recoveryDiagnosticSnapshot.recentWarnings = [
            "\(diagnosticTimestamp) — shard_info refresh failed (will retry) {\"error\":\"all archive endpoints failed; last error: endpoint returned only zero shard sizes\"}"
        ]
        let recoveryAssessment = ChainProgressEvaluator.evaluate(recoveryDiagnosticSnapshot, now: diagnosticNow)
        expect(
            recoveryAssessment.state == .archiveRecovery,
            "shared archive convergence is distinguished from a local stall")
        let recoveryReport = NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: recoveryDiagnosticSnapshot,
                initialRefreshComplete: true,
                serviceAvailable: true,
                networkAssessment: diagnosticNetwork,
                networkInspection: diagnosticInspection,
                firewall: readyFirewall,
                qclientReady: true,
                qclientCompatible: true,
                now: diagnosticNow
            )
        )
        let recoveryFrameCheck = recoveryReport.checks.first(where: { $0.id == "frame-progress" })
        expect(recoveryFrameCheck?.state == .waiting, "archive recovery is a waiting state, not a failure")
        expect(recoveryFrameCheck?.repair == nil, "archive recovery never offers a local restart")
        expect(recoveryReport.actionCount == 0, "expected recovery messages do not create false repair actions")
        var relaunchedRecoverySnapshot = recoveryDiagnosticSnapshot
        relaunchedRecoverySnapshot.frameLastAdvancedAt = nil
        expect(
            ChainProgressEvaluator.evaluate(relaunchedRecoverySnapshot, now: diagnosticNow).state == .archiveRecovery,
            "strong fresh recovery evidence survives an app relaunch without an in-memory frame baseline"
        )
        let relaunchedRecoveryReport = NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: relaunchedRecoverySnapshot,
                initialRefreshComplete: true,
                serviceAvailable: true,
                networkAssessment: diagnosticNetwork,
                networkInspection: diagnosticInspection,
                firewall: readyFirewall,
                qclientReady: true,
                qclientCompatible: true,
                now: diagnosticNow
            )
        )
        expect(
            relaunchedRecoveryReport.checks.first(where: { $0.id == "frame-progress" })?.state == .waiting,
            "diagnostics immediately restore archive recovery after app relaunch"
        )
        let firewallOffReport = NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: healthyDiagnosticSnapshot,
                initialRefreshComplete: true,
                serviceAvailable: true,
                networkAssessment: diagnosticNetwork,
                networkInspection: diagnosticInspection,
                firewall: ManagedFirewallStatus(
                    globalEnabled: false,
                    blockAllEnabled: false,
                    stealthEnabled: false,
                    nodeRule: .missing,
                    managedByQuilNode: false,
                    verifiedAt: diagnosticNow
                ),
                qclientReady: true,
                qclientCompatible: true,
                now: diagnosticNow
            )
        )
        expect(
            firewallOffReport.checks.first(where: { $0.id == "firewall" })?.state == .advisory,
            "disabled firewall is advisory rather than a false reachability failure"
        )

    }
}
