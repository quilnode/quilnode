import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class NetworkReadinessTests: XCTestCase {
    func testProcessMetricsAndNetworkReadiness() async {
        expect(
            !NodeObservationPhase.checkingProcess.hasDeterminedProcessState,
            "unobserved process is not treated as stopped")
        expect(
            NodeObservationPhase.loadingTelemetry.hasDeterminedProcessState, "process fast path establishes presence")
        expect(!NodeObservationPhase.loadingTelemetry.hasLiveTelemetry, "process presence does not fabricate telemetry")
        expect(NodeObservationPhase.ready.hasLiveTelemetry, "ready phase exposes complete telemetry")

        let processObservation = await LocalNodeCollector().observeProcess()
        expect(processObservation.latency >= 0, "process observation reports latency")
        expect(processObservation.latency < 2.5, "managed process observation stays on the fast path")

        let boundedSuccess = BoundedCommandRunner.run(
            executable: "/bin/echo",
            arguments: ["bounded-ok"],
            timeout: 2,
            maximumOutputBytes: 1_024
        )
        expect(boundedSuccess.exitCode == 0 && boundedSuccess.output == "bounded-ok", "bounded command success")
        let boundedOutput = BoundedCommandRunner.run(
            executable: "/usr/bin/yes",
            arguments: [String(repeating: "x", count: 256)],
            timeout: 3,
            maximumOutputBytes: 4_096
        )
        expect(boundedOutput.exceededOutputLimit && boundedOutput.exitCode != 0, "bounded command output limit")
        let boundedTimeout = BoundedCommandRunner.run(
            executable: "/bin/sleep",
            arguments: ["2"],
            timeout: 0.1,
            maximumOutputBytes: 1_024
        )
        expect(boundedTimeout.timedOut && boundedTimeout.exitCode != 0, "bounded command timeout")
        setenv("QUILNODE_SELFTEST_INHERITED_SECRET", "must-not-leak", 1)
        let boundedEnvironment = BoundedCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: [],
            timeout: 2,
            maximumOutputBytes: 8_192
        )
        unsetenv("QUILNODE_SELFTEST_INHERITED_SECRET")
        expect(
            !boundedEnvironment.output.contains("QUILNODE_SELFTEST_INHERITED_SECRET"),
            "bounded command environment allowlist"
        )

        let log = """
            2030-01-02T03:04:05Z\tinfo\tfile.rs:1\tnode status\t{"frame":500001,"peers":12,"pending_joins":0}
            2030-01-02T03:04:35Z\tinfo\tfile.rs:1\tnode status\t{"frame":500004,"peers":13,"archive_peers":2,"pending_joins":3,"active_shards":0,"total_allocations":3,"frames_received":1234,"router_drops":0}
            """

        if let status = NodeStatusParser.latestStatus(in: log) {
            expect(NodeStatusParser.uint64(status, "frame") == 500_004, "latest frame parsing")
            expect(NodeStatusParser.int(status, "peers") == 13, "peer parsing")
            expect(NodeStatusParser.int(status, "pending_joins") == 3, "pending join parsing")
            expect(NodeStatusParser.int(status, "total_allocations") == 3, "allocation parsing")
        } else {
            XCTFail("node status JSON parsing")
        }

        let nodeInfoOutput = """
            signature check passed
            Peer ID: QmExamplePeer
            Version: 2.1.0.25
            Prover Address: deadbeefcafefeed
            Seniority: 12,345,678
            Running Workers: 3
            Active Workers: 0
            Frame Number: 500004
            """

        let info = NodeInfoParser.parse(nodeInfoOutput)
        expect(info.version == "2.1.0.25", "version parsing")
        expect(info.seniority == 12_345_678, "seniority parsing")
        expect(info.runningWorkers == 3, "worker parsing")
        expect(info.frame == 500_004, "node-info frame parsing")

        let peerInfoOutput = """
            Peer ID: QmFalconPeer
            Legacy Peer ID (Ed448): QmSeniorityIdentity
            """
        let peerInfo = NodeInfoParser.parse(peerInfoOutput)
        expect(peerInfo.legacyPeerID == "QmSeniorityIdentity", "legacy identity parsing")

        let metrics = """
            # HELP libp2p_connected_peers Current connected peers
            libp2p_connected_peers 59
            libp2p_connections_established_total{direction="Outbound"} 42
            libp2p_connections_established_total{direction="Inbound"} 274
            """
        expect(NodeMetricsParser.value("libp2p_connected_peers", in: metrics) == 59, "live metrics parsing")
        expect(
            NodeMetricsParser.value(
                "libp2p_connections_established_total",
                labels: ["direction": "Inbound"],
                in: metrics
            ) == 274,
            "inbound metric label parsing"
        )
        expect(
            NodeMetricsParser.value(
                "libp2p_connections_established_total",
                labels: ["direction": "Outbound"],
                in: metrics
            ) == 42,
            "outbound metric label parsing"
        )

        let workerLog = """
            2030-01-02T04:05:06Z\tinfo\tquil_engine/src/thread_worker.rs:445\tworker rocksdb memory\t{"core_id":2}
            2030-01-02T04:05:06Z\tinfo\tquil_engine/src/thread_worker.rs:445\tworker rocksdb memory\t{"core_id":4}
            """
        expect(WorkerRuntimeParser.localThreadWorkerCount(in: workerLog) == 4, "local thread worker count parsing")

        let listeningInspection = NetworkLocalInspection(
            localIPv4: "10.254.254.49",
            gatewayIPv4: "10.254.254.1",
            interfaceName: "en1",
            interfaceDisplayName: "Wi-Fi",
            firewallState: .enabled,
            tcpListeners: [8_336, 8_340],
            inspectionSucceeded: true
        )
        let verifiedNetwork = NetworkReadinessEvaluator.evaluate(
            node: NodeSnapshot(
                isRunning: true,
                peers: 59,
                inboundConnectionsEstablished: 1,
                processUptime: "01:00:00"
            ),
            inspection: listeningInspection
        )
        expect(verifiedNetwork.state == .inboundVerified, "inbound evidence verifies reachability")

        let routerReview = NetworkReadinessEvaluator.evaluate(
            node: NodeSnapshot(
                isRunning: true,
                peers: 59,
                inboundConnectionsEstablished: 0,
                processUptime: "00:30:00"
            ),
            inspection: listeningInspection
        )
        expect(routerReview.state == .reviewRouter, "missing inbound evidence prompts router review after grace period")

        let localListenerIssue = NetworkReadinessEvaluator.evaluate(
            node: NodeSnapshot(isRunning: true, peers: 59, processUptime: "01:00:00"),
            inspection: NetworkLocalInspection(
                tcpListeners: [8_340],
                inspectionSucceeded: true
            )
        )
        expect(
            localListenerIssue.state == .localConfigurationIssue,
            "missing local listener takes precedence over router advice")
        expect(localListenerIssue.missingMasterPorts == [8_336], "missing listener identifies exact port")
        expect(NodeProcessUptimeParser.seconds(from: "2-01:02:03") == 176_523, "process uptime parsing")

        let localThreadPlan = NetworkPortPlan.residentialTCP(localWorkerCount: 9)
        expect(
            localThreadPlan.required.map(\.portLabel) == ["8336", "8340"], "local thread plan limits required ports")
        expect(
            localThreadPlan.clusterOnly.first?.portLabel == "25000–25008", "cluster worker range uses N worker ports")

        let customProfile = NetworkPortProfile(
            kind: .custom,
            peerPort: 18_336,
            peerTransport: .udp,
            streamPort: 18_340
        )
        let customPlan = NetworkPortPlan.plan(for: customProfile, localWorkerCount: 9)
        let customInspection = NetworkLocalInspection(
            tcpListeners: [18_340],
            udpListeners: [18_336],
            inspectionSucceeded: true
        )
        expect(customPlan.profile == customProfile, "custom port plan keeps its typed profile")
        expect(
            customPlan.validation(in: customInspection).isReadyToActivate,
            "custom UDP and TCP listeners verify by transport")
        expect(
            !customPlan.validation(in: NetworkLocalInspection(tcpListeners: [18_340], inspectionSucceeded: true))
                .isReadyToActivate,
            "custom profile cannot activate before the peer listener is observed"
        )
        let collidingProfile = NetworkPortProfile(
            kind: .custom, peerPort: 18_336, peerTransport: .tcp, streamPort: 18_336)
        expect(
            !NetworkPortPlan.plan(for: collidingProfile, localWorkerCount: 1)
                .validation(in: customInspection).isStructurallyValid,
            "peer and stream ports cannot collide"
        )
        let customReadiness = NetworkReadinessEvaluator.evaluate(
            node: NodeSnapshot(isRunning: true, peers: 20, processUptime: "00:02:00"),
            inspection: customInspection,
            portPlan: customPlan
        )
        expect(
            customReadiness.state == .waitingForEvidence, "readiness evaluator honors a verified custom transport plan")

        let sanitizedEndpoint = PrivacySanitizer.display("dial 10.254.254.49:8336", enabled: true)
        expect(
            sanitizedEndpoint == "dial •••.•••.•••.•••:•••••",
            "privacy sanitizer masks an address and service port together")
        expect(
            PrivacySanitizer.display("listen /ip4/0.0.0.0/udp/18336/quic-v1", enabled: true)
                == "listen /ip4/•••.•••.•••.•••/udp/•••••/quic-v1",
            "privacy sanitizer masks contextual multiaddress ports"
        )
        expect(
            PrivacySanitizer.display("stream port 54321 at frame 500004", enabled: true)
                == "stream port ••••• at frame 500004",
            "privacy sanitizer masks labeled ports without redacting unrelated protocol values"
        )
        expect(
            PrivacySanitizer.display("stream port 54321", enabled: false) == "stream port 54321",
            "privacy sanitizer is presentation-only"
        )

        let managedFirewall = ManagedFirewallStatus(
            globalEnabled: true,
            blockAllEnabled: false,
            stealthEnabled: false,
            nodeRule: .allowed,
            managedByQuilNode: true
        )
        expect(managedFirewall.isReady, "managed firewall requires global protection and an allowed node rule")
        expect(
            !ManagedFirewallStatus(
                globalEnabled: true,
                blockAllEnabled: true,
                stealthEnabled: false,
                nodeRule: .allowed,
                managedByQuilNode: true
            ).isReady,
            "block-all overrides an otherwise allowed node rule"
        )

        let homeGateway = GatewayRouteClassifier.assess(listeningInspection)
        expect(homeGateway.kind == .privateLAN, "RFC1918 default route is classified as a private LAN gateway")
        expect(homeGateway.isSafeBrowserTarget, "private LAN gateway is eligible for a local browser suggestion")
        expect(homeGateway.interfaceDisplayName == "Wi-Fi", "gateway keeps the human-readable interface name")

        let vpnGateway = GatewayRouteClassifier.assess(
            NetworkLocalInspection(gatewayIPv4: "10.8.0.1", interfaceName: "utun4", inspectionSucceeded: true)
        )
        expect(vpnGateway.kind == .tunnel, "VPN route is not presented as the home router")
        expect(!vpnGateway.isSafeBrowserTarget, "VPN gateway cannot be opened automatically")

        let publicGateway = GatewayRouteClassifier.assess(
            NetworkLocalInspection(gatewayIPv4: "203.0.113.1", interfaceName: "en0", inspectionSucceeded: true)
        )
        expect(publicGateway.kind == .publicAddress, "public next hop is classified conservatively")
        expect(!publicGateway.isSafeBrowserTarget, "public next hop cannot be opened automatically")
        expect(GatewayRouteClassifier.isRFC1918("172.31.255.254"), "RFC1918 boundary is accepted")
        expect(!GatewayRouteClassifier.isRFC1918("172.32.0.1"), "non-RFC1918 address is rejected")

    }
}
