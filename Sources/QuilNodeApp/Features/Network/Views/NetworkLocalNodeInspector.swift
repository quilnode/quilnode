import QuilNodeCore
import SwiftUI

struct NetworkLocalNodeInspector: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let node: NetworkLocalNodePresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                header
                participationSection
                sectionDivider
                allocationSection
                if !node.workers.isEmpty {
                    sectionDivider
                    workerSection
                }
                sectionDivider
                rewardSection
                sectionDivider
                runtimeSection
                sectionDivider
                identitySection
                sourceFooter
            }
            .padding(16)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .controlSurface(tint: statusTint)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MY NODE")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(theme.colors.secondaryText)
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(theme.colors.accent.opacity(0.12))
                    Circle().strokeBorder(theme.colors.accent.opacity(0.70), lineWidth: 1.2)
                    Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(node.isRunning ? "Local node online" : "Local node offline")
                        .font(.headline)
                    Text(node.version.map { "Runtime \($0)" } ?? "Runtime version unavailable")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
    }

    private var participationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(node.participation.title, systemImage: node.participation.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusTint)
            Text(node.participation.detail)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var allocationSection: some View {
        section("Participation") {
            LazyVGrid(columns: inspectorColumns, spacing: 8) {
                compactMetric(
                    "Workers running",
                    node.runningWorkers.map(String.init) ?? "—",
                    tint: theme.colors.info,
                    privacyField: .hardwareProfile
                )
                compactMetric(
                    "Workers assigned",
                    String(node.allocatedWorkers),
                    tint: theme.colors.accentSecondary,
                    privacyField: .hardwareProfile
                )
                compactMetric(
                    "Active allocations",
                    String(node.activeAllocations),
                    tint: theme.colors.success,
                    privacyField: .activeShardCount
                )
                compactMetric(
                    "Joining allocations",
                    String(node.joiningAllocations),
                    tint: theme.colors.warning,
                    privacyField: .allocationCount
                )
                compactMetric(
                    "All allocations",
                    String(node.totalAllocations),
                    tint: theme.colors.primaryText,
                    privacyField: .allocationCount
                )
                if node.allocationCoverage.hasEvidence {
                    compactMetric(
                        "Healthy coverage",
                        String(node.allocationCoverage.healthy),
                        tint: theme.colors.success,
                        privacyField: .allocationCount
                    )
                    compactMetric(
                        "Needs coverage",
                        String(node.allocationCoverage.needsCoverage),
                        tint: theme.colors.warning,
                        privacyField: .allocationCount
                    )
                }
            }
            if node.totalAllocations > 0 {
                datum(
                    "Allocation rings",
                    node.localRings.compactLabel,
                    privacyField: .shardAllocation
                )
            }
            Text("Workers are local processes. Allocations are registry assignments. Coverage describes their shards.")
                .font(.system(size: 9.2))
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rewardSection: some View {
        section("Rewards") {
            VStack(alignment: .leading, spacing: 5) {
                Label(node.participation.rewardTitle, systemImage: node.participation.rewardSystemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(rewardTint)
                Text(node.participation.rewardDetail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let perFrame = node.estimatedRewardPerFrame,
                let perDay = node.estimatedRewardPerTargetDay
            {
                datum("Model estimate / frame", "~\(perFrame) QUIL", privacyField: .rewardActivity)
                datum("At target cadence / day", "~\(perDay) QUIL", privacyField: .rewardActivity)
                Text("Shard-model estimate only; it is not proof of work or payment.")
                    .font(.system(size: 9.2))
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            datum(
                "QUIL balance",
                node.quilBalance?.compactDecimal ?? "—",
                privacyField: node.quilBalance == nil ? nil : .quilBalance
            )
            datum(
                "Last credit",
                node.lastRewardCreditFrame.map { "Frame \($0.grouped)" } ?? "None observed",
                privacyField: node.lastRewardCreditFrame == nil ? nil : .rewardActivity
            )
        }
    }

    private var workerSection: some View {
        section("Worker roster") {
            if redactionReasons.contains(.privacy) {
                ForEach(0..<PrivacyLayoutPolicy.collectionPlaceholderCount, id: \.self) { _ in
                    workerRow(nil)
                }
            } else {
                ForEach(node.workers) { worker in
                    workerRow(worker)
                }
            }
            Text("Available and total storage are reported by the local qclient.")
                .font(.system(size: 9.2))
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var runtimeSection: some View {
        section("Local activity") {
            datum(
                "Frame pace",
                node.framesPerMinute.map { String(format: "%.2f / min", $0) } ?? "—"
            )
            datum(
                "Inbound accepted",
                node.inboundConnections.map(String.init) ?? "—",
                privacyField: .networkActivity
            )
            datum(
                "Outbound opened",
                node.outboundConnections.map(String.init) ?? "—",
                privacyField: .networkActivity
            )
            datum(
                "Node CPU",
                node.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—",
                privacyField: .hardwareProfile
            )
            datum(
                "Node memory",
                node.memoryMB.map { String(format: "%.0f MB", $0) } ?? "—",
                privacyField: .hardwareProfile
            )
            datum("Node uptime", node.processUptime ?? "—", privacyField: .nodeUptime)
        }
    }

    private var identitySection: some View {
        section("Identity evidence") {
            datum(
                "Seniority",
                node.seniorityIsObserved ? node.seniority.grouped : "—",
                privacyField: node.seniorityIsObserved ? .seniority : nil
            )
            if let proverAddress = node.proverAddress {
                datum("Prover", proverAddress.compactIdentifier, privacyField: .networkIdentifier)
            }
            if let peerID = node.peerID {
                datum("Peer", peerID.compactIdentifier, privacyField: .networkIdentifier)
            }
            if let quilAccount = node.quilAccount {
                datum("Account", quilAccount.compactIdentifier, privacyField: .networkIdentifier)
            }
        }
    }

    private var sourceFooter: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield")
            Text("Local node, qclient and process evidence")
        }
        .font(.system(size: 9.2, design: .monospaced))
        .foregroundStyle(theme.colors.secondaryText)
    }

    private var sectionDivider: some View {
        Divider().overlay(theme.colors.border.opacity(0.5))
    }

    private var inspectorColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(theme.colors.secondaryText)
            content()
        }
    }

    private func compactMetric(
        _ label: String,
        _ value: String,
        tint: Color,
        privacyField: PrivacyField?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 16, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 8.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 43, alignment: .leading)
        .padding(8)
        .background(theme.colors.canvas.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func datum(_ label: String, _ value: String, privacyField: PrivacyField? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer(minLength: 4)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private func workerRow(_ worker: LocalWorkerObservation?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            workerDatum(
                "Worker",
                worker.map { String($0.coreID) } ?? "0",
                privacyField: .hardwareProfile,
                width: 42
            )
            workerDatum(
                "Shard",
                worker?.filter.compactIdentifier ?? "hidden",
                privacyField: .shardAllocation,
                width: 68
            )
            workerDatum(
                "Storage",
                worker.map { "\($0.availableStorage) / \($0.totalStorage)" } ?? "hidden",
                privacyField: .hardwareProfile,
                width: nil
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(theme.colors.canvas.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func workerDatum(
        _ label: String,
        _ value: String,
        privacyField: PrivacyField,
        width: CGFloat?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .medium))
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private var statusTint: Color {
        switch node.participation.state {
        case .activeAllocations: theme.colors.success
        case .joining, .allocated, .networkRecovery: theme.colors.warning
        case .awaitingAllocation: theme.colors.info
        case .offline: theme.colors.danger
        }
    }

    private var rewardTint: Color {
        switch node.participation.rewardState {
        case .creditObserved: theme.colors.success
        case .networkWaiting, .noCreditObserved: theme.colors.warning
        case .notEligible: theme.colors.secondaryText
        }
    }
}
