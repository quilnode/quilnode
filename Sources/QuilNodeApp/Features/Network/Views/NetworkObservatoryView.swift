import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryView: View {
    @Environment(\.dashboardLayoutClass) private var layoutClass
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons
    @EnvironmentObject private var monitor: NodeMonitor

    @State private var selection: NetworkObservatorySelection? = .localNode
    @State private var filter = NetworkObservatoryFilter.all
    @State private var query = ""
    @State private var zoom: CGFloat = 1

    private var presentation: NetworkObservatoryPresentation {
        .make(snapshot: monitor.snapshot)
    }

    private var visibleShards: [NetworkShardPresentation] {
        presentation.visibleShards(
            filter: filter,
            query: query,
            includesLocalAssignments: !redactionReasons.contains(.privacy)
        )
    }

    private var availableFilters: [NetworkObservatoryFilter] {
        redactionReasons.contains(.privacy) ? [.all, .attention] : NetworkObservatoryFilter.allCases
    }

    private var featuredShardIDs: Set<String> {
        presentation.featuredShardIDs(
            revealsLocalTopology: !redactionReasons.contains(.privacy),
            limit: layoutClass.isCompact ? 7 : 9
        )
    }

    private var selectedShard: NetworkShardPresentation? {
        guard case .shard(let id) = selection else { return nil }
        return visibleShards.first { $0.id == id }
            ?? presentation.shards.first { $0.id == id }
    }

    private var selectedShardID: String? {
        guard case .shard(let id) = selection else { return nil }
        return id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            observatoryHeader
            NetworkObservatoryScopeGuide()
            NetworkObservatoryMetricStrip(presentation: presentation)

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
        .onChange(of: query) { _, _ in ensureSelection() }
        .onChange(of: redactionReasons) { _, reasons in
            if reasons.contains(.privacy), filter == .local { filter = .all }
            ensureSelection()
        }
    }

    private var observatoryHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                headerTitle
                Spacer(minLength: 8)
                headerControls
            }
            VStack(alignment: .leading, spacing: 10) {
                headerTitle
                headerControls
            }
        }
    }

    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Network observatory")
                .font(.headline)
            Text("Shared shard state through this node · stable layout, not geography")
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private var headerControls: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(availableFilters) { candidate in
                    Button {
                        filter = candidate
                    } label: {
                        if candidate == filter {
                            Label(candidate.title, systemImage: "checkmark")
                        } else {
                            Text(candidate.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(filter.title)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.colors.secondaryText)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.colors.primaryText)
                .padding(.horizontal, 9)
                .frame(width: 144, height: 28)
                .contentShape(Rectangle())
                .controlSurface()
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .accessibilityLabel("Shard scope")
            searchField
            zoomControls
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.secondaryText)
            TextField("Shard, ring or worker", text: $query)
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
        .frame(width: 190, height: 28)
        .controlSurface()
        .help("Searches the shard table retained by this node, including local worker assignments")
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
                inspector
                    .frame(width: 282)
            }
            .frame(height: 510)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                topology.frame(height: layoutClass.isCompact ? 360 : 420)
                inspector
                    .frame(minHeight: 250)
            }
        }
    }

    private var topology: some View {
        ZStack {
            NetworkObservatoryCanvas(
                shards: visibleShards,
                featuredIDs: featuredShardIDs.intersection(visibleShards.map(\.id)),
                selectedID: selectedShardID,
                isLocalNodeSelected: selection == .localNode,
                onSelectShard: { selection = .shard($0) },
                onSelectLocalNode: { selection = .localNode },
                zoom: zoom,
                archiveSources: presentation.archiveSources,
                localAllocationCount: presentation.localAllocationCount
            )

            if visibleShards.isEmpty
                && !presentation.localNode.matches(
                    query,
                    includesPrivateIdentifiers: !redactionReasons.contains(.privacy)
                )
            {
                ContentUnavailableView(
                    query.isEmpty ? "No matching shards" : "Not in this local observation",
                    systemImage: "scope",
                    description: Text(
                        query.isEmpty
                            ? "Change the scope or clear the filter."
                            : "Search covers known shards and this node's worker assignments. Arbitrary network identities require a separate index."
                    )
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

    @ViewBuilder
    private var inspector: some View {
        switch selection {
        case .localNode:
            NetworkLocalNodeInspector(node: presentation.localNode)
        case .shard:
            NetworkShardObservatoryInspector(shard: selectedShard)
        case nil:
            NetworkShardObservatoryInspector(shard: nil)
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
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalizedQuery.isEmpty,
            presentation.localNode.matches(
                normalizedQuery,
                includesPrivateIdentifiers: !hidesLocalAssociation
            )
        {
            selection = .localNode
            return
        }

        if case .localNode = selection, normalizedQuery.isEmpty { return }
        if case .shard(let selectedID) = selection {
            let currentSelectionIsEligible = visibleShards.contains { shard in
                shard.id == selectedID && (!hidesLocalAssociation || !shard.observation.isAllocated)
            }
            if currentSelectionIsEligible { return }
        }

        if hidesLocalAssociation {
            selection =
                visibleShards.first(where: { !$0.observation.isAllocated })
                .map { .shard($0.id) }
                ?? visibleShards.first.map { .shard($0.id) }
        } else {
            selection =
                visibleShards.first(where: { $0.observation.isAllocated })
                .map { .shard($0.id) }
                ?? visibleShards.first.map { .shard($0.id) }
        }
    }
}
