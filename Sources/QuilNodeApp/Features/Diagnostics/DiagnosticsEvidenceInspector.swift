import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticsEvidenceInspector: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass
    let check: NodeDiagnosticCheck?
    let onRepair: (NodeDiagnosticRepair) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Local evidence dossier")
                    .font(.headline)
                if let check {
                    Text("— \(check.title)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(diagnosticTint(check.state, theme: theme))
                }
                Spacer()
                Label("Privacy-safe", systemImage: "lock.shield.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.colors.success)
            }
            .padding(12)
            Divider()

            if let check {
                Group {
                    if !dashboardLayoutClass.isWide {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 2),
                            alignment: .leading,
                            spacing: 0
                        ) {
                            evidenceCell("What was tested", value: check.summary, systemImage: "checklist")
                            evidenceCell(
                                "Observed local signal",
                                value: check.evidence,
                                systemImage: "waveform.badge.magnifyingglass"
                            )
                            evidenceCell("Why this follows", value: conclusion(for: check), systemImage: "function")
                            responseCell(check)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 0) {
                            evidenceCell("What was tested", value: check.summary, systemImage: "checklist")
                            divider
                            evidenceCell(
                                "Observed local signal",
                                value: check.evidence,
                                systemImage: "waveform.badge.magnifyingglass"
                            )
                            divider
                            evidenceCell("Why this follows", value: conclusion(for: check), systemImage: "function")
                            divider
                            responseCell(check)
                        }
                    }
                }

                Divider()
                HStack(spacing: 14) {
                    Text(diagnosticStateLabel(check.state))
                        .font(.caption2.bold())
                        .foregroundStyle(diagnosticTint(check.state, theme: theme))
                    if let observedAt = check.observedAt {
                        HStack(spacing: 0) {
                            Text("Observed ")
                            PrivacyProtectedText(
                                value: observedAt.formatted(date: .abbreviated, time: .standard),
                                field: .localTimestamp
                            )
                        }
                    }
                    Spacer()
                    Text("Repairs never run silently")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                ContentUnavailableView(
                    "No evidence selected",
                    systemImage: "text.page.badge.magnifyingglass",
                    description: Text("Select a finding or test in the proof matrix.")
                )
                .frame(maxWidth: .infinity, minHeight: 140)
            }
        }
        .controlSurface(tint: check.map { diagnosticTint($0.state, theme: theme) } ?? theme.colors.info)
    }

    private func evidenceCell(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var divider: some View {
        Rectangle().fill(Color.secondary.opacity(0.14)).frame(width: 1, height: 104).padding(.vertical, 10)
    }

    private func responseCell(_ check: NodeDiagnosticCheck) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Scoped response", systemImage: "wrench.and.screwdriver")
                .font(.caption.weight(.semibold))
            Text(DiagnosticRepairPresentation.scope(check.repair))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label(
                DiagnosticRepairPresentation.safety(check.repair),
                systemImage: "checkmark.shield.fill"
            )
            .font(.caption2.weight(.medium))
            .foregroundStyle(theme.colors.success)
            if let repair = check.repair {
                Button(
                    DiagnosticRepairPresentation.label(repair),
                    systemImage: DiagnosticRepairPresentation.icon(repair)
                ) {
                    onRepair(repair)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func conclusion(for check: NodeDiagnosticCheck) -> String {
        switch check.state {
        case .checking: "The probe has not completed, so no pass or failure is claimed."
        case .passed: "The observed signal satisfies this local readiness condition."
        case .waiting: "Local operation is healthy; the missing progress depends on shared network state."
        case .advisory: "The signal does not prove failure, but it deserves operator review."
        case .failed: "The required local readiness condition is absent or invalid."
        }
    }
}

struct DiagnosticsProvenanceStrip: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass

    var body: some View {
        Group {
            if !dashboardLayoutClass.isWide {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 2),
                    spacing: 0
                ) {
                    item("Local tests only", "No diagnostic data is sent.", "desktopcomputer")
                    item("No keys read", "No private key bytes enter the app.", "key.slash")
                    item("No explorer dependency", "Conclusions use local evidence.", "network.slash")
                    item("Explicit repairs", "State changes require a visible action.", "hand.raised.fill")
                }
            } else {
                HStack(spacing: 0) {
                    item("Local tests only", "No diagnostic data is sent.", "desktopcomputer")
                    Divider().frame(height: 30)
                    item("No keys read", "No private key bytes enter the app.", "key.slash")
                    Divider().frame(height: 30)
                    item("No explorer dependency", "Conclusions use local evidence.", "network.slash")
                    Divider().frame(height: 30)
                    item("Explicit repairs", "State changes require a visible action.", "hand.raised.fill")
                }
            }
        }
        .padding(.vertical, 10)
        .controlSurface(tint: theme.colors.success)
    }

    private func item(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(theme.colors.success)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
