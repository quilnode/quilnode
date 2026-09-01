import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryView: View {
    @Environment(\.dashboardLayoutClass) private var layoutClass
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject private var shardHistory: NetworkShardHistoryStore

    @State private var selection: NetworkObservatorySelection? = .localNode
    @State private var lens = NetworkObservatoryLens.all
    @State private var query = ""
    @State private var zoom: CGFloat = 1

    private var presentation: NetworkObservatoryPresentation {
        .make(snapshot: monitor.snapshot)
    }

    private var visibleShards: [NetworkShardPresentation] {
        presentation.visibleShards(
            lens: lens,
            query: query,
            includesLocalAssignments: !redactionReasons.contains(.privacy),
            recentChanges: recentChanges
        )
    }

    private var recentChanges: [String: NetworkShardChangeRecord] {
        shardHistory.changes(at: presentation.observedAt ?? Date())
    }

    private var availableLenses: [NetworkObservatoryLens] {
        redactionReasons.contains(.privacy)
            ? NetworkObservatoryLens.allCases.filter { $0 != .local }
            : NetworkObservatoryLens.allCases
    }

    private var featuredShardIDs: Set<String> {
        presentation.featuredShardIDs(
            in: visibleShards,
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
        .onAppear {
            recordObservation()
            ensureSelection()
        }
        .onChange(of: presentation.observedAt) { _, _ in
            recordObservation()
            ensureSelection()
        }
        .onChange(of: visibleShards.map(\.id)) { _, _ in ensureSelection() }
        .onChange(of: query) { _, _ in ensureSelection() }
        .onChange(of: redactionReasons) { _, reasons in
            if reasons.contains(.privacy), lens == .local { lens = .all }
            ensureSelection()
        }
    }

    private var observatoryHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                headerTitle
                Spacer(minLength: 8)
                NetworkObservatoryToolbar(
                    lens: $lens,
                    query: $query,
                    zoom: $zoom,
                    availableLenses: availableLenses
                )
            }
            VStack(alignment: .leading, spacing: 10) {
                headerTitle
                NetworkObservatoryToolbar(
                    lens: $lens,
                    query: $query,
                    zoom: $zoom,
                    availableLenses: availableLenses
                )
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

            if visibleShards.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: lens.systemImage,
                    description: Text(emptyStateDetail)
                )
                .foregroundStyle(theme.colors.secondaryText)
                .allowsHitTesting(false)
            }

            lensBadge

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
            NetworkShardObservatoryInspector(
                shard: selectedShard,
                recentChange: selectedShard.flatMap { recentChanges[$0.id] }
            )
        case nil:
            NetworkShardObservatoryInspector(shard: nil, recentChange: nil)
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

    private var lensBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: lens.systemImage)
                .foregroundStyle(theme.colors.accentSecondary)
            Text(lens.title)
                .fontWeight(.semibold)
            Text("·")
                .foregroundStyle(theme.colors.muted)
            Text("\(visibleShards.count) shown")
                .foregroundStyle(theme.colors.secondaryText)
        }
        .font(.system(size: 9.5, design: .monospaced).monospacedDigit())
        .foregroundStyle(theme.colors.primaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(theme.colors.canvas.opacity(0.90), in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(13)
        .allowsHitTesting(false)
        .accessibilityLabel("\(lens.title), \(visibleShards.count) shards shown")
    }

    private var emptyStateTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No matches in \(lens.title.lowercased())"
        }
        return switch lens {
        case .all, .largestStorage, .highestReward: "No shard evidence"
        case .local: "No local allocations"
        case .attention: "No shards need coverage"
        case .recentlyChanged:
            shardHistory.hasBaseline ? "No recent shard changes" : "Building a local baseline"
        }
    }

    private var emptyStateDetail: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Clear the search or choose another lens. Arbitrary network identities require a separate index."
        }
        return switch lens {
        case .all, .largestStorage, .highestReward:
            "The local qclient has not returned a usable shard table."
        case .local:
            "This node is not currently linked to any shard in the local observation."
        case .attention:
            "Every locally observed shard currently meets the six-prover target."
        case .recentlyChanged:
            shardHistory.hasBaseline
                ? "No public shard metric changed during the last 24 hours of local observations."
                : "Changes appear after QuilNode can compare two local shard observations."
        }
    }

    private func recordObservation() {
        shardHistory.observe(
            monitor.snapshot.networkShards ?? [],
            observedAt: presentation.observedAt
        )
    }
}
