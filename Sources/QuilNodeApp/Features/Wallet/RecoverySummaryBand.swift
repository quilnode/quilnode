import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct RecoverySummaryBand: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.dashboardLayoutClass) private var dashboardLayoutClass

    let presentation: RecoveryWorkspacePresentation
    let active: ManagedKeyset

    var body: some View {
        Group {
            if dashboardLayoutClass.isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    activeIdentity
                    Divider()
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: 3),
                        alignment: .leading,
                        spacing: 0
                    ) {
                        summaryFacts(fixedWidths: false)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    activeIdentity
                        .frame(maxWidth: .infinity, alignment: .leading)
                    divider
                    summaryFacts(fixedWidths: true)
                }
            }
        }
        .padding(14)
        .frame(minHeight: 112)
        .controlSurface(tint: readinessTint)
    }

    @ViewBuilder
    private func summaryFacts(fixedWidths: Bool) -> some View {
        summaryFact(
            title: "Automatic rollback",
            value: rollbackStage.value,
            detail: rollbackStage.state.label,
            symbol: "checkmark.shield.fill",
            tint: rollbackStage.state.tint(in: theme),
            privacyField: rollbackStage.privacyField
        )
        .frame(width: fixedWidths ? 190 : nil)
        if fixedWidths { divider }
        summaryFact(
            title: "Separate backup",
            value: separateStage.state == .verified ? "Recorded" : "None recorded",
            detail: separateStage.state.label,
            symbol: separateStage.state == .verified
                ? "externaldrive.badge.checkmark" : "externaldrive.badge.exclamationmark",
            tint: separateStage.state.tint(in: theme),
            privacyField: nil
        )
        .frame(width: fixedWidths ? 166 : nil)
        if fixedWidths { divider }
        summaryFact(
            title: "Stored identities",
            value: String(presentation.storedIdentityCount),
            detail: "One can be active",
            symbol: "person.2.fill",
            tint: theme.colors.accent,
            privacyField: .recoveryMetadata
        )
        .frame(width: fixedWidths ? 150 : nil)
    }

    private var activeIdentity: some View {
        HStack(spacing: 13) {
            DashboardCircleIcon(
                systemImage: "person.badge.key.fill",
                tint: theme.colors.accent,
                size: 48
            )
            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE IDENTITY PACKAGE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.secondaryText)
                HStack(spacing: 7) {
                    PrivacyProtectedText(
                        value: active.name,
                        field: .recoveryMetadata,
                        mask: .identifier
                    )
                    .font(.title3.bold())
                    Text("ACTIVE")
                        .font(.system(size: 7, weight: .black, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(theme.colors.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.colors.success.opacity(0.12), in: Capsule())
                }
                Text("\(active.format.label) · \(active.isManaged ? "Managed locally" : "Protection required")")
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                Text(presentation.readinessTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(readinessTint)
            }
        }
        .padding(.trailing, 12)
    }

    private var divider: some View {
        Divider()
            .overlay(theme.colors.border.opacity(0.6))
            .frame(height: 72)
    }

    private var rollbackStage: RecoveryLayerPresentation {
        presentation.stages.first(where: { $0.layer == .automaticRollback })!
    }

    private var separateStage: RecoveryLayerPresentation {
        presentation.stages.first(where: { $0.layer == .separateBackup })!
    }

    private var readinessTint: Color {
        if presentation.stages.contains(where: { $0.state == .review }) {
            return theme.colors.warning
        }
        if presentation.stages.contains(where: { $0.state == .recommended }) {
            return theme.colors.warning
        }
        return theme.colors.success
    }

    private func summaryFact(
        title: String,
        value: String,
        detail: String,
        symbol: String,
        tint: Color,
        privacyField: PrivacyField?
    ) -> some View {
        HStack(spacing: 10) {
            DashboardCircleIcon(systemImage: symbol, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.55)
                    .foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(tint)
            }
        }
        .padding(.horizontal, 12)
    }
}

extension RecoveryLayerState {
    func tint(in theme: QuilTheme) -> Color {
        switch self {
        case .verified: theme.colors.success
        case .review: theme.colors.warning
        case .recommended: theme.colors.warning
        }
    }
}
