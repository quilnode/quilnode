import QuilNodeCore
import SwiftUI

extension DashboardView {
    func overviewResourcePanel(layoutClass: DashboardLayoutClass) -> some View {
        let snapshot = monitor.snapshot
        let current = nodeObservation.hasLiveTelemetry && snapshot.isRunning
        let cpu = CPUUsagePresentation(snapshot: snapshot)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("On this Mac").font(.subheadline.weight(.semibold))
                Text("Node process · CPU share of total Mac capacity")
                    .font(.caption).foregroundStyle(theme.colors.secondaryText)
                Spacer(minLength: 0)
            }
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), alignment: .leading), count: layoutClass.isCompact ? 2 : 4),
                spacing: 14
            ) {
                overviewResource("CPU", current ? cpu.valueText : "—", symbol: "cpu", detail: cpu.detailText)
                overviewResource(
                    "Memory", current ? RuntimeResourceFormatter.memory(snapshot.memoryMB) : "—", symbol: "memorychip",
                    detail: "Resident memory · binary units")
                overviewResource(
                    "Process uptime", current ? RuntimeResourceFormatter.uptime(snapshot.processUptime) : "—",
                    symbol: "clock", detail: "Since this process started")
                overviewResource(
                    "Local frame pace",
                    current ? snapshot.framesPerMinute.map { String(format: "%.2f / min", $0) } ?? "—" : "—",
                    symbol: "waveform.path", detail: "Observed pace · not a target", field: nil)
            }
        }
        .padding(16).controlSurface()
        .padding(.horizontal, 20).padding(.top, 14)
    }

    private func overviewResource(
        _ title: String, _ value: String, symbol: String, detail: String, field: PrivacyField? = .hardwareProfile
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: field)
                .font(.system(size: 21, weight: .semibold, design: theme.typography.dataDesign).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.8)
            PrivacyProtectedText(value: detail, field: title == "CPU" ? .hardwareProfile : nil)
                .font(.caption2).foregroundStyle(theme.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func overviewProtocolDetails(layoutClass: DashboardLayoutClass) -> some View {
        DisclosureGroup("Epoch, seniority & network map", isExpanded: $overviewDetailsExpanded) {
            if overviewDetailsExpanded {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) {
                        overviewEpochDetails.frame(minWidth: 250)
                        overviewMap.frame(width: 420, height: 250)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        overviewEpochDetails
                        overviewMap.frame(height: 250)
                    }
                }
                .padding(.top, 16)
            }
        }
        .font(.subheadline.weight(.medium))
        .padding(16).controlSurface()
        .padding(.horizontal, 20).padding(.top, 14)
    }

    private var overviewMap: some View {
        DashboardOverviewConstellation(
            snapshot: monitor.snapshot, hasLiveTelemetry: nodeObservation.hasLiveTelemetry,
            onOpenNetwork: { openOverviewNetwork(.observatory) })
    }

    private var overviewEpochDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(nodeObservation.value("Epoch \(currentEpoch.grouped)"))
                .font(.title2.weight(.semibold)).foregroundStyle(theme.colors.frame)
            ProgressView(value: nodeObservation.hasLiveTelemetry ? epochProgress : 0)
                .progressViewStyle(QuilLinearProgressStyle(tint: theme.colors.frame))
                .accessibilityLabel("Local epoch progress")
            Text(nodeObservation.value("\(framesUntilEpoch.grouped) frames to next boundary · \(epochCompactETA)"))
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
            Text("ETA follows local frame pace; it is an estimate.")
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
            Divider()
            HStack {
                Text("Chain seniority").font(.subheadline)
                Spacer()
                PrivacyProtectedText(
                    value: nodeObservation.value(
                        monitor.snapshot.hasSeniorityObservation ? monitor.snapshot.seniority.grouped : "—"),
                    field: .seniority
                )
                .font(.subheadline.monospacedDigit())
            }
            Button("View public identities") { destination = .identity }
                .buttonStyle(.link)
            Text("The map is illustrative. Coverage counts memberships, not recent frame production.")
                .font(.caption).foregroundStyle(theme.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
