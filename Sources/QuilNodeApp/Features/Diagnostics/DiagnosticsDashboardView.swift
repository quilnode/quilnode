import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Diagnostics owns tests and evidence, not a second copy of dashboard status.
/// Every conclusion identifies the signal it used; every repair is scoped,
/// explicit, and reversible where the platform permits.
struct DiagnosticsDashboardView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject private var lifecycle: NodeLifecycleController
    @EnvironmentObject private var network: NetworkReadinessCoordinator
    @EnvironmentObject private var installer: InstallationCoordinator
    @EnvironmentObject private var privacyMode: PrivacyModeController

    let onNavigate: (DashboardDestination) -> Void

    @State private var isScanning = false
    @State private var scanStage = "Ready"
    @State private var lastScanAt: Date?
    @State private var expandedChecks: Set<String> = []
    @State private var pendingConfirmation: NodeDiagnosticRepair?
    @State private var repairMessage: String?

    private var report: NodeDiagnosticReport {
        let preflight = installer.preflight
        return NodeDiagnosticEvaluator.evaluate(
            NodeDiagnosticContext(
                snapshot: monitor.snapshot,
                initialRefreshComplete: monitor.hasCompletedInitialRefresh,
                serviceAvailable: lifecycle.passwordlessServiceAvailable,
                networkAssessment: network.assessment,
                networkInspection: network.inspection,
                firewall: network.firewall.nodeRule == .unavailable ? nil : network.firewall,
                qclientReady: preflight.map { $0.qclientStatus?.isReady == true },
                qclientCompatible: preflight.map(\.qclientCompatibleWithNode)
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            reportHero
            ForEach(NodeDiagnosticCategory.allCases, id: \.rawValue) { category in
                checkGroup(category)
            }
            recentEvidence
            provenance
        }
        .task {
            if lastScanAt == nil {
                await runFullScan()
            }
        }
        .alert(item: $pendingConfirmation) { repair in
            Alert(
                title: Text(confirmationTitle(for: repair)),
                message: Text(confirmationMessage(for: repair)),
                primaryButton: .default(Text(confirmationButton(for: repair))) {
                    Task { await executeConfirmed(repair) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var reportHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(overallTint.opacity(0.13))
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: overallIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(overallTint)
                }
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text(overallTitle)
                    .font(.title3.bold())
                Text(overallDetail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                if isScanning {
                    Text(scanStage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.colors.accent)
                } else if let lastScanAt {
                    HStack(spacing: 0) {
                        Text("Last full check ")
                        PrivacyProtectedText(
                            value: lastScanAt.formatted(date: .omitted, time: .standard),
                            field: .localTimestamp
                        )
                    }
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    statusCount(title: "Passed", value: report.passedCount, tint: theme.colors.success)
                    if report.waitingCount > 0 {
                        statusCount(title: "Waiting", value: report.waitingCount, tint: theme.colors.info)
                    }
                    statusCount(
                        title: "Review", value: report.actionCount,
                        tint: report.actionCount == 0 ? theme.colors.secondaryText : theme.colors.warning)
                }
                Button {
                    Task { await runFullScan() }
                } label: {
                    if isScanning {
                        Label("Running checks", systemImage: "waveform.path.ecg")
                    } else {
                        Label("Run full check", systemImage: "stethoscope")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)
            }
        }
        .padding(18)
        .controlSurface(tint: overallTint)
    }

    private func statusCount(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(String(value))
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
        }
        .frame(minWidth: 48)
    }

    private func checkGroup(_ category: NodeDiagnosticCategory) -> some View {
        let checks = report.checks.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(categoryTitle(category), systemImage: categoryIcon(category))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                Text(groupStatus(checks))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                    DiagnosticCheckRow(
                        check: check,
                        isExpanded: expandedChecks.contains(check.id),
                        onToggle: { toggle(check.id) },
                        onRepair: { repair in handle(repair) }
                    )
                    if index < checks.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .controlSurface()
        }
    }

    @ViewBuilder
    private var recentEvidence: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recent local evidence", systemImage: "text.page.badge.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
                    .padding(.horizontal, 4)
                Spacer()
                Button("Copy safe report", systemImage: "doc.on.doc") {
                    copySafeReport()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 0) {
                if monitor.snapshot.recentWarnings.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.colors.success)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No warning lines in the latest local sample")
                                .font(.subheadline.weight(.semibold))
                            Text(
                                "This is one signal only; the checks above still evaluate progress, peers, listeners, and tooling independently."
                            )
                            .font(.caption)
                            .foregroundStyle(theme.colors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(16)
                } else {
                    ForEach(Array(monitor.snapshot.recentWarnings.prefix(12).enumerated()), id: \.offset) {
                        index, warning in
                        HStack(alignment: .top, spacing: 10) {
                            Image(
                                systemName: recoveryEvidenceIsWaiting
                                    ? "hourglass.circle.fill" : "exclamationmark.circle.fill"
                            )
                            .foregroundStyle(recoveryEvidenceIsWaiting ? theme.colors.info : theme.colors.warning)
                            .padding(.top, 1)
                            Text(PrivacySanitizer.display(warning, enabled: privacyMode.isEnabled))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(13)
                        if index < min(monitor.snapshot.recentWarnings.count, 12) - 1 {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }
            .controlSurface(
                tint: monitor.snapshot.recentWarnings.isEmpty
                    ? theme.colors.success
                    : (recoveryEvidenceIsWaiting ? theme.colors.info : theme.colors.warning))

            if let repairMessage {
                Label(repairMessage, systemImage: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var provenance: some View {
        HStack(spacing: 16) {
            Label("Tests run locally", systemImage: "lock.shield.fill")
            Label("No keys read", systemImage: "key.slash")
            Label("No explorer dependency", systemImage: "network.slash")
            Spacer()
            Text("Repairs are never run silently")
        }
        .font(.caption2)
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 4)
    }

    private var recoveryEvidenceIsWaiting: Bool {
        report.checks.first(where: { $0.id == "recent-evidence" })?.state == .waiting
    }

    private func groupStatus(_ checks: [NodeDiagnosticCheck]) -> String {
        let passed = checks.filter { $0.state == .passed }.count
        let waiting = checks.filter { $0.state == .waiting }.count
        if waiting > 0 {
            return "\(passed) passed · \(waiting) waiting"
        }
        return "\(passed)/\(checks.count) passed"
    }

    private func runFullScan() async {
        guard !isScanning else { return }
        isScanning = true
        repairMessage = nil

        scanStage = "Refreshing process, frame, identity, and metrics"
        await monitor.refresh(forceNodeInfo: true)

        scanStage = "Verifying the authorized operator service"
        await lifecycle.refreshServiceStatus()

        scanStage = "Inspecting listeners, inbound evidence, and macOS Firewall"
        await network.refresh()

        scanStage = "Verifying local tooling provenance"
        await installer.inspectForDiagnostics()

        lastScanAt = Date()
        scanStage = "Complete"
        isScanning = false
    }

    private func handle(_ repair: NodeDiagnosticRepair) {
        switch repair {
        case .refreshEvidence:
            Task { await runFullScan() }
        case .startNode:
            Task {
                await lifecycle.perform(.start, monitor: monitor)
                await runFullScan()
            }
        case .restartNode, .configureFirewall:
            pendingConfirmation = repair
        case .openNetwork:
            onNavigate(.network)
        case .openUpdates:
            onNavigate(.updates)
        case .repairQClient:
            Task {
                repairMessage = "Installing and verifying the qclient that matches this node…"
                await installer.prepareAndInstallQClient()
                repairMessage = installer.error ?? "qclient repair finished; running checks again."
                await runFullScan()
            }
        }
    }

    private func executeConfirmed(_ repair: NodeDiagnosticRepair) async {
        switch repair {
        case .restartNode:
            repairMessage = "Restarting the node through the authorized local service…"
            await lifecycle.perform(.restart, monitor: monitor)
            repairMessage = lifecycle.lastError ?? lifecycle.lastMessage
            await runFullScan()
        case .configureFirewall:
            repairMessage = "Applying and verifying the minimum macOS Firewall rule…"
            await network.configureFirewall()
            repairMessage = network.firewallError ?? "macOS Firewall verification finished."
            await runFullScan()
        default:
            handle(repair)
        }
    }

    private func toggle(_ id: String) {
        withAnimation(motion.disclosure) {
            if expandedChecks.contains(id) {
                expandedChecks.remove(id)
            } else {
                expandedChecks.insert(id)
            }
        }
    }

    private func copySafeReport() {
        let lines = report.checks.map {
            "\($0.category.rawValue.capitalized) · \($0.state.rawValue.capitalized) · \($0.title)"
        }
        let text = (["QuilNode local diagnostic summary"] + lines).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        repairMessage = "Copied a privacy-safe summary without identifiers, ports, counts, paths, or raw logs."
    }

    private var overallTitle: String {
        if isScanning { return "Running local checks" }
        return switch report.overallState {
        case .checking: "Evidence still collecting"
        case .passed: "All tested systems are ready"
        case .waiting: "Network recovery in progress"
        case .advisory: "Review recommended"
        case .failed: "Action required"
        }
    }

    private var overallDetail: String {
        if isScanning { return "Each test updates as its local evidence arrives." }
        return switch report.overallState {
        case .checking: "No failure is declared until the relevant probe has completed."
        case .passed: "Process, progress, network, and tooling checks passed with current local evidence."
        case .waiting:
            "This node is healthy and waiting for shared archive state. Keep it running; no local repair is recommended."
        case .advisory: "The node may continue running, but one or more signals deserve review."
        case .failed: "At least one readiness condition failed. Expand it for evidence and a scoped repair."
        }
    }

    private var overallTint: Color {
        switch report.overallState {
        case .checking: theme.colors.info
        case .passed: theme.colors.success
        case .waiting: theme.colors.info
        case .advisory: theme.colors.warning
        case .failed: theme.colors.danger
        }
    }

    private var overallIcon: String {
        switch report.overallState {
        case .checking: "ellipsis.circle.fill"
        case .passed: "checkmark.seal.fill"
        case .waiting: "hourglass.circle.fill"
        case .advisory: "exclamationmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    private func categoryTitle(_ category: NodeDiagnosticCategory) -> String {
        switch category {
        case .runtime: "Runtime & evidence"
        case .progress: "Chain progress"
        case .network: "Network readiness"
        case .tooling: "Tooling & provenance"
        }
    }

    private func categoryIcon(_ category: NodeDiagnosticCategory) -> String {
        switch category {
        case .runtime: "bolt.horizontal.circle"
        case .progress: "forward.frame"
        case .network: "network"
        case .tooling: "checkmark.shield"
        }
    }

    private func confirmationTitle(for repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .restartNode: "Restart the node?"
        case .configureFirewall: "Configure macOS Firewall?"
        default: "Run this repair?"
        }
    }

    private func confirmationMessage(for repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .restartNode:
            "The process will stop briefly and resume with the same node configuration and keyset. Stores are not deleted."
        case .configureFirewall:
            "QuilNode will add and verify only the installed node executable, keep the firewall enabled, and disable block-all mode if necessary. Router settings are not changed."
        default:
            "QuilNode will run the scoped local repair shown by this check."
        }
    }

    private func confirmationButton(for repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .restartNode: "Restart"
        case .configureFirewall: "Configure"
        default: "Continue"
        }
    }
}
