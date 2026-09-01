import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryView: View {
    @Environment(\.dashboardLayoutClass) private var layoutClass
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons
    @EnvironmentObject private var monitor: NodeMonitor

    @State private var selectedID: String?
    @State private var filter = NetworkObservatoryFilter.all
    @State private var query = ""
    @State private var zoom: CGFloat = 1

    private var presentation: NetworkObservatoryPresentation {
        .make(snapshot: monitor.snapshot)
    }

    private var visibleShards: [NetworkShardPresentation] {
        presentation.visibleShards(filter: filter, query: query)
    }

    private var availableFilters: [NetworkObservatoryFilter] {
        redactionReasons.contains(.privacy) ? [.all, .attention] : NetworkObservatoryFilter.allCases
    }

    private var selectedShard: NetworkShardPresentation? {
        visibleShards.first { $0.id == selectedID }
            ?? presentation.shards.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NetworkObservatoryMetricStrip(presentation: presentation)

            observatoryHeader

            switch presentation.evidenceState {
            case .loading:
                loadingState
            case .unavailable where presentation.shards.isEmpty:
                unavailableState
            case .current, .stale, .unavailable:
                topologyWorkspace
            }

            NetworkObservatoryEvidenceRail(presentation: presentation)
        }
        .onAppear { ensureSelection() }
        .onChange(of: visibleShards.map(\.id)) { _, _ in ensureSelection() }
        .onChange(of: redactionReasons) { _, reasons in
            if reasons.contains(.privacy), filter == .local { filter = .all }
            ensureSelection()
        }
    }

    private var observatoryHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { headerContent }
            VStack(alignment: .leading, spacing: 10) { headerContent }
        }
    }

    @ViewBuilder
    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Shard constellation")
                .font(.headline)
            Text("Real shard state from this node · stable layout, not geography")
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
        }
        Spacer(minLength: 8)
        Picker("Shard scope", selection: $filter) {
            ForEach(availableFilters) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 144)
        .accessibilityLabel("Shard scope")
        searchField
        zoomControls
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.secondaryText)
            TextField("Filter or ring", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.secondaryText)
                .accessibilityLabel("Clear shard search")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 170, height: 28)
        .controlSurface()
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            zoomButton("minus", adjustment: -0.1)
            Text("\(Int(zoom * 100))%")
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
                .frame(width: 42)
            zoomButton("plus", adjustment: 0.1)
        }
        .frame(height: 28)
        .controlSurface()
    }

    private func zoomButton(_ systemImage: String, adjustment: CGFloat) -> some View {
        Button {
            zoom = min(max(zoom + adjustment, 0.72), 1.18)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.colors.accent)
        .accessibilityLabel(adjustment > 0 ? "Zoom in" : "Zoom out")
    }

    @ViewBuilder
    private var topologyWorkspace: some View {
        if layoutClass.isWide {
            HStack(alignment: .top, spacing: 12) {
                topology
                NetworkObservatoryInspector(shard: selectedShard)
                    .frame(width: 268)
            }
            .frame(height: 480)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                topology.frame(height: layoutClass.isCompact ? 360 : 420)
                NetworkObservatoryInspector(shard: selectedShard)
                    .frame(minHeight: 250)
            }
        }
    }

    private var topology: some View {
        ZStack {
            NetworkObservatoryCanvas(
                shards: visibleShards,
                selectedID: $selectedID,
                zoom: zoom
            )

            if visibleShards.isEmpty {
                ContentUnavailableView(
                    "No matching shards",
                    systemImage: "scope",
                    description: Text("Change the scope or clear the filter.")
                )
                .foregroundStyle(theme.colors.secondaryText)
            }

            if redactionReasons.contains(.privacy) {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash")
                    Text("Local allocation links hidden")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.privacy)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(theme.colors.canvas.opacity(0.90), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(14)
                .allowsHitTesting(false)
            }
        }
    }

    private var loadingState: some View {
        QuilLoadingIndicator(
            label: "Reading shard topology",
            detail: "The local qclient is collecting shard coverage and allocation evidence."
        )
        .frame(maxWidth: .infinity, minHeight: 360)
        .controlSurface(tint: theme.colors.info)
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: monitor.snapshot.isRunning ? "scope" : "power")
                .font(.system(size: 28))
                .foregroundStyle(theme.colors.warning)
            Text(monitor.snapshot.isRunning ? "Shard topology is not available yet" : "The node is offline")
                .font(.headline)
            Text(
                monitor.snapshot.isRunning
                    ? "QuilNode has not received a complete local qclient shard observation. Refresh once the node is ready."
                    : "Start the local node to observe network shard state."
            )
            .font(.caption)
            .foregroundStyle(theme.colors.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
            if monitor.snapshot.isRunning {
                Button("Read local topology") {
                    Task { await monitor.refresh(forceNodeInfo: true) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .controlSurface(tint: theme.colors.warning)
    }

    private func ensureSelection() {
        let hidesLocalAssociation = redactionReasons.contains(.privacy)
        let currentSelectionIsEligible = visibleShards.contains { shard in
            shard.id == selectedID && (!hidesLocalAssociation || !shard.observation.isAllocated)
        }
        guard !currentSelectionIsEligible else { return }
        if hidesLocalAssociation {
            selectedID =
                visibleShards.first(where: { !$0.observation.isAllocated })?.id
                ?? visibleShards.first?.id
        } else {
            selectedID =
                visibleShards.first(where: { $0.observation.isAllocated })?.id
                ?? visibleShards.first?.id
        }
    }
}
