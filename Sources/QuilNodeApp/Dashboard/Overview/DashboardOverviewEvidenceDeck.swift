import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    func overviewEvidenceDeck(layoutClass: DashboardLayoutClass) -> some View {
        let evidence = overviewOperatorPresentation
        let cards = overviewEvidenceCards(evidence)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("At a glance")
                    .font(.system(size: 13, weight: .semibold))
                Text("Local observations · details on selection")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer(minLength: 12)
            }

            Group {
                if layoutClass.isWide {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(cards) { card in
                            OverviewEvidenceCard(card: card) {
                                if card.destination == .network {
                                    openOverviewNetwork(card.id == "network" ? .connectivity : .observatory)
                                } else {
                                    destination = card.destination
                                }
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 480), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(cards) { card in
                            OverviewEvidenceCard(card: card) {
                                if card.destination == .network {
                                    openOverviewNetwork(card.id == "network" ? .connectivity : .observatory)
                                } else {
                                    destination = card.destination
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    func overviewLatestActivity(_ event: NodeActivityEvent) -> some View {
        Button {
            destination = .activity
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 13) {
                    overviewLatestActivityIcon(event)
                    overviewLatestActivityCopy(event)
                    Spacer(minLength: 12)
                    overviewLatestActivityEvidence(event)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(theme.colors.info)
                }
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 11) {
                        overviewLatestActivityIcon(event)
                        overviewLatestActivityCopy(event)
                    }
                    overviewLatestActivityEvidence(event)
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .controlSurface(tint: overviewActivityTint(event).opacity(0.45))
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: overviewActivityTint(event))
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .accessibilityHint("Opens the local activity journal")
    }

    private func overviewEvidenceCards(_ evidence: OverviewOperatorPresentation) -> [OverviewEvidenceCardDescriptor] {
        let snapshot = monitor.snapshot
        let wallet = TokenAmountPresentation(
            evidence.rewards.hasModernWallet ? evidence.rewards.claimable : evidence.rewards.balance)
        let frame = snapshot.lastGlobalHeadFrame > 0 ? snapshot.lastGlobalHeadFrame : snapshot.frame
        return [
            OverviewEvidenceCardDescriptor(
                id: "rewards", title: "Wallet", systemImage: "wallet.bifold", tint: theme.colors.wallet,
                primary: .init(
                    label: evidence.rewards.hasModernWallet ? "Claimable rewards · QUIL" : "Balance · QUIL",
                    value: nodeObservation.value(wallet.compact), privacyField: .quilBalance),
                secondary: nil, metadataLabel: "",
                metadataValue: ObservationFreshness(observedAt: snapshot.balanceUpdatedAt).label,
                metadataPrivacyField: .localTimestamp,
                detail: evidence.rewards.hasModernWallet
                    ? "Rewards require minting. View all balances" : "View exact balance and identities",
                destination: .identity, observedAt: snapshot.balanceUpdatedAt),
            OverviewEvidenceCardDescriptor(
                id: "progress", title: "Chain progress", systemImage: "square.stack.3d.up", tint: theme.colors.frame,
                primary: .init(
                    label: snapshot.lastGlobalHeadFrame > 0 ? "Local GLOBAL head" : "Local frame",
                    value: nodeObservation.value(frame > 0 ? frame.grouped : "—"), privacyField: nil),
                secondary: nil, metadataLabel: "Received",
                metadataValue: nodeObservation.value(
                    snapshot.lastReceivedFrame > 0 ? snapshot.lastReceivedFrame.grouped : "—"),
                metadataPrivacyField: nil, detail: "Local observation, not a global sync guarantee.",
                destination: .activity,
                observedAt: snapshot.lastGlobalHeadFrame > 0
                    ? snapshot.proverStatusUpdatedAt : snapshot.metricsUpdatedAt),
            OverviewEvidenceCardDescriptor(
                id: "participation", title: "Assignments", systemImage: "square.grid.3x3.fill",
                tint: theme.colors.accentSecondary,
                primary: .init(
                    label: "Active allocations",
                    value: nodeObservation.value(evidence.participation.activeAllocations.map(String.init) ?? "—"),
                    privacyField: .activeShardCount),
                secondary: nil, metadataLabel: "Joining",
                metadataValue: nodeObservation.value(evidence.participation.joiningAllocations.map(String.init) ?? "—"),
                metadataPrivacyField: .allocationCount,
                detail: "Registry membership. Worker execution below.", destination: .network,
                observedAt: snapshot.proverStatusUpdatedAt),
            OverviewEvidenceCardDescriptor(
                id: "network", title: "Connectivity", systemImage: "network", tint: theme.colors.info,
                primary: .init(
                    label: "Connected peers",
                    value: nodeObservation.value(
                        snapshot.metricsUpdatedAt != nil ? String(evidence.network.peers) : "—"),
                    privacyField: .networkActivity),
                secondary: nil, metadataLabel: "Archives",
                metadataValue: nodeObservation.value(evidence.network.archiveSources.map(String.init) ?? "—"),
                metadataPrivacyField: .networkActivity,
                detail: "Verify listeners, firewall and inbound traffic", destination: .network,
                observedAt: snapshot.metricsUpdatedAt),
        ]
    }

    private func overviewLatestActivityIcon(_ event: NodeActivityEvent) -> some View {
        DashboardCircleIcon(
            systemImage: overviewActivitySystemImage(event),
            tint: overviewActivityTint(event),
            size: 39
        )
    }

    private func overviewLatestActivityCopy(_ event: NodeActivityEvent) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("LATEST MEANINGFUL CHANGE")
                .protocolSectionLabel(color: theme.colors.secondaryText)
            Text(event.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.colors.primaryText)
            Text(event.detail)
                .font(.system(size: 10.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewLatestActivityEvidence(_ event: NodeActivityEvent) -> some View {
        HStack(spacing: 12) {
            if let value = event.sensitiveValue {
                PrivacyProtectedText(value: value, field: event.privacyField)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(overviewActivityTint(event))
                    .lineLimit(1)
            }
            PrivacyProtectedText(
                value: event.timestamp.formatted(date: .abbreviated, time: .shortened),
                field: .localTimestamp
            )
            .font(.caption2.monospacedDigit())
            .foregroundStyle(theme.colors.secondaryText)
            Text(event.actionState == .none ? "Observed" : event.actionState.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(overviewActivityTint(event))
        }
    }

    private func overviewActivityTint(_ event: NodeActivityEvent) -> Color {
        switch event.category {
        case .runtime: theme.colors.success
        case .proving: theme.colors.accent
        case .network: theme.colors.info
        case .rewards: theme.colors.wallet
        case .identity: theme.colors.accentSecondary
        }
    }

    private func overviewActivitySystemImage(_ event: NodeActivityEvent) -> String {
        switch event.category {
        case .runtime: "waveform.path.ecg"
        case .proving: "square.grid.3x3.fill"
        case .network: "network"
        case .rewards: "sparkles"
        case .identity: "link"
        }
    }
}

private struct OverviewEvidenceValue {
    let label: String
    let value: String
    let privacyField: PrivacyField?
}

private struct OverviewEvidenceCardDescriptor: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let tint: Color
    let primary: OverviewEvidenceValue
    let secondary: OverviewEvidenceValue?
    let metadataLabel: String
    let metadataValue: String
    let metadataPrivacyField: PrivacyField?
    let detail: String
    let destination: DashboardDestination
    var observedAt: Date? = nil
}

private struct OverviewEvidenceCard: View {
    @Environment(\.quilTheme) private var theme

    let card: OverviewEvidenceCardDescriptor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: card.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(card.tint)
                    Text(card.title.uppercased())
                        .protocolSectionLabel(color: theme.colors.secondaryText)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.colors.secondaryText.opacity(0.75))
                }

                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    evidenceValue(card.primary)
                    if let secondary = card.secondary {
                        evidenceValue(secondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(card.metadataLabel)
                    PrivacyProtectedText(
                        value: card.metadataValue,
                        field: card.metadataPrivacyField
                    )
                    .fontWeight(.semibold)
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)

                if card.id != "rewards" {
                    PrivacyProtectedText(
                        value: ObservationFreshness(observedAt: card.observedAt).label, field: .localTimestamp
                    )
                    .font(.caption2).foregroundStyle(theme.colors.secondaryText)
                }
                Text(card.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(2)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .controlSurface(tint: card.tint.opacity(0.48))
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: card.tint)
        .accessibilityHint("Opens \(card.destination.title)")
    }

    private func evidenceValue(_ value: OverviewEvidenceValue) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value.label)
                .font(.system(size: 11))
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value.value, field: value.privacyField)
                .font(
                    .system(
                        size: 27 * theme.typography.scale,
                        weight: .semibold,
                        design: theme.typography.dataDesign
                    ).monospacedDigit()
                )
                .foregroundStyle(card.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .quilLiveValueTransition(value: value.value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
