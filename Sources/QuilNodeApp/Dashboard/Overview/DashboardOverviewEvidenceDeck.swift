import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var overviewEvidenceDeck: some View {
        let evidence = overviewOperatorPresentation
        let cards = overviewEvidenceCards(evidence)

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("Operator evidence")
                    .font(.system(size: 13, weight: .semibold))
                Text("The four answers needed at a glance")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer(minLength: 12)
            }

            Group {
                if dashboardLayoutClass.isWide {
                    HStack(spacing: 10) {
                        ForEach(cards) { card in
                            OverviewEvidenceCard(card: card) {
                                destination = card.destination
                            }
                        }
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 480), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(cards) { card in
                            OverviewEvidenceCard(card: card) {
                                destination = card.destination
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

    private func overviewEvidenceCards(
        _ evidence: OverviewOperatorPresentation
    ) -> [OverviewEvidenceCardDescriptor] {
        [
            OverviewEvidenceCardDescriptor(
                id: "participation",
                title: "Participation",
                systemImage: "square.grid.3x3.fill",
                tint: evidence.participation.activeAllocations > 0
                    ? theme.colors.success : theme.colors.warning,
                primary: OverviewEvidenceValue(
                    label: "Active",
                    value: nodeObservation.value(String(evidence.participation.activeAllocations)),
                    privacyField: .activeShardCount
                ),
                secondary: OverviewEvidenceValue(
                    label: "Joining",
                    value: nodeObservation.value(String(evidence.participation.joiningAllocations)),
                    privacyField: .allocationCount
                ),
                metadataLabel: "Workers",
                metadataValue: nodeObservation.value(
                    evidence.participation.runningWorkers.map(String.init) ?? "—"
                ),
                metadataPrivacyField: .hardwareProfile,
                detail: "Workers may serve either allocation state.",
                destination: .network
            ),
            OverviewEvidenceCardDescriptor(
                id: "network",
                title: "Network",
                systemImage: "point.3.connected.trianglepath.dotted",
                tint: theme.colors.info,
                primary: OverviewEvidenceValue(
                    label: "Peers",
                    value: nodeObservation.value(String(evidence.network.peers)),
                    privacyField: .networkActivity
                ),
                secondary: OverviewEvidenceValue(
                    label: "Archives",
                    value: nodeObservation.value(evidence.network.archiveSources.map(String.init) ?? "—"),
                    privacyField: .networkActivity
                ),
                metadataLabel: "Inbound",
                metadataValue: nodeObservation.value(evidence.network.inboundObserved ? "Observed" : "Not observed"),
                metadataPrivacyField: .networkActivity,
                detail: "Connectivity observed from this Mac.",
                destination: .network
            ),
            OverviewEvidenceCardDescriptor(
                id: "identity",
                title: "Identity",
                systemImage: "person.text.rectangle",
                tint: theme.colors.accentSecondary,
                primary: OverviewEvidenceValue(
                    label: "Seniority",
                    value: nodeObservation.value(
                        evidence.identity.seniority > 0 ? evidence.identity.seniority.grouped : "—"
                    ),
                    privacyField: .seniority
                ),
                secondary: nil,
                metadataLabel: "Source",
                metadataValue: nodeObservation.detail(DashboardCopy.Overview.chainRegistry),
                metadataPrivacyField: nil,
                detail: "Consensus identity reported locally.",
                destination: .identity
            ),
            OverviewEvidenceCardDescriptor(
                id: "rewards",
                title: "Rewards",
                systemImage: "sparkles",
                tint: rewardTint,
                primary: OverviewEvidenceValue(
                    label: "QUIL balance",
                    value: nodeObservation.value(evidence.rewards.balance?.compactDecimal ?? "—"),
                    privacyField: .quilBalance
                ),
                secondary: OverviewEvidenceValue(
                    label: "Last credit",
                    value: nodeObservation.value(
                        evidence.rewards.lastCreditFrame.map { "Frame \($0.grouped)" } ?? "None"
                    ),
                    privacyField: .rewardActivity
                ),
                metadataLabel: "Evidence",
                metadataValue: nodeObservation.detail(rewardStatusTitle),
                metadataPrivacyField: nil,
                detail: "Observed credits, never estimated earnings.",
                destination: .activity
            ),
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

                Text(card.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(2)
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
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
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value.value, field: value.privacyField)
                .font(
                    .system(
                        size: 18 * theme.typography.scale,
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
