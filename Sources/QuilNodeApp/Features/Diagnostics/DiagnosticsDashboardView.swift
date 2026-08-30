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
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject private var lifecycle: NodeLifecycleController
    @EnvironmentObject private var network: NetworkReadinessCoordinator
    @EnvironmentObject private var installer: InstallationCoordinator
    @EnvironmentObject private var privacyMode: PrivacyModeController

    let onNavigate: (DashboardDestination) -> Void

    @State private var isScanning = false
    @State private var scanStage = "Ready"
    @State private var lastScanAt: Date?
    @State private var selectedCheckID: String?
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
        let presentation = DiagnosticsPresentation.make(report: report)
        return VStack(alignment: .leading, spacing: 12) {
            diagnosticsHeader
            DiagnosticsSummaryBand(
                report: report,
                presentation: presentation,
                isScanning: isScanning,
                scanStage: scanStage,
                lastScanAt: lastScanAt
            )
            HStack(alignment: .top, spacing: 10) {
                DiagnosticsFindingsQueue(
                    findings: presentation.findings,
                    selectedID: selectedCheck?.id,
                    onSelect: { selectedCheckID = $0 }
                )
                DiagnosticsProofMatrix(
                    categories: presentation.categories,
                    selectedID: selectedCheck?.id,
                    onSelect: { selectedCheckID = $0 }
                )
            }
            DiagnosticsEvidenceInspector(check: selectedCheck, onRepair: handle)
            recentEvidence
            DiagnosticsProvenanceStrip()
        }
        .task {
            if selectedCheckID == nil {
                selectedCheckID = presentation.selectedFallbackID
            }
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

    private var diagnosticsHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LOCAL ASSURANCE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.colors.accent)
                Text("Diagnostics")
                    .font(.largeTitle.weight(.bold))
                Text("Local evidence, explicit conclusions, scoped repair.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Copy safe report", systemImage: "doc.on.doc") {
                copySafeReport()
            }
            .buttonStyle(.bordered)
            Button {
                Task { await runFullScan() }
            } label: {
                Label(isScanning ? "Running checks" : "Run full check", systemImage: "stethoscope")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
        }
    }

    private var selectedCheck: NodeDiagnosticCheck? {
        if let selectedCheckID,
            let check = report.checks.first(where: { $0.id == selectedCheckID })
        {
            return check
        }
        let presentation = DiagnosticsPresentation.make(report: report)
        return presentation.findings.first ?? report.checks.first
    }

    @ViewBuilder
    private var recentEvidence: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recent local evidence", systemImage: "text.page.badge.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
                    .padding(.horizontal, 4)
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

    private var recoveryEvidenceIsWaiting: Bool {
        report.checks.first(where: { $0.id == "recent-evidence" })?.state == .waiting
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
        let refreshedPresentation = DiagnosticsPresentation.make(report: report)
        selectedCheckID =
            refreshedPresentation.findings.first?.id
            ?? refreshedPresentation.selectedFallbackID
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

    private func copySafeReport() {
        let lines = report.checks.map {
            "\($0.category.rawValue.capitalized) · \($0.state.rawValue.capitalized) · \($0.title)"
        }
        let text = (["QuilNode local diagnostic summary"] + lines).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        repairMessage = "Copied a privacy-safe summary without identifiers, ports, counts, paths, or raw logs."
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
