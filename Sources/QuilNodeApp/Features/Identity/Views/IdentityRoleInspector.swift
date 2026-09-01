import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct IdentityRoleInspector: View {
    @Environment(\.quilTheme) private var theme

    let role: IdentityRolePresentation
    let seniority: Int64
    let seniorityIsObserved: Bool
    let seniorityTrend: SeniorityTrend
    let chainEvidenceSource: String
    let chainEvidenceKind: String
    let chainEvidenceAt: Date?
    let onCopy: (String?) -> Void
    let onOpen: (URL?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            inspectorHeader
            Divider().overlay(theme.colors.border.opacity(0.66))

            VStack(alignment: .leading, spacing: 13) {
                explanation
                Divider().overlay(theme.colors.border.opacity(0.52))
                identifier

                if role.kind == .seniority {
                    Divider().overlay(theme.colors.border.opacity(0.52))
                    seniorityEvidence
                }

                Divider().overlay(theme.colors.border.opacity(0.52))
                provenance
                Divider().overlay(theme.colors.border.opacity(0.52))
                actions

                Spacer(minLength: 6)
                custodyBoundary
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 584, alignment: .topLeading)
        .controlSurface()
        .accessibilityElement(children: .contain)
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected identity")
                        .font(.headline)
                    Text("Public · read only")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                Button {
                    onCopy(role.value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .disabled(!role.isAvailable)
                .help("Copy public identifier")
                .accessibilityLabel("Copy public identifier")
            }

            HStack(spacing: 10) {
                DashboardCircleIcon(
                    systemImage: role.kind.symbol,
                    tint: theme.colors.success,
                    size: 38
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(role.kind.title)
                        .font(.title3.bold())
                    Text(role.kind.detail)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
        .padding(14)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 6) {
            inspectorLabel(role.kind.explanationTitle)
            Text(role.kind.explanation)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var identifier: some View {
        VStack(alignment: .leading, spacing: 6) {
            inspectorLabel("Public identifier")
            HStack(spacing: 6) {
                PrivacyProtectedText(
                    value: role.displayedValue,
                    field: role.privacyField
                )
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)

                Spacer(minLength: 4)

                Button {
                    onCopy(role.value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(!role.isAvailable)
                .help("Copy public identifier")
            }
        }
    }

    private var seniorityEvidence: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    inspectorLabel("Chain seniority")
                    PrivacyProtectedText(
                        value: seniorityIsObserved
                            ? seniority.formatted(.number.grouping(.automatic))
                            : "Reading…",
                        field: seniorityIsObserved ? .seniority : nil
                    )
                    .font(.subheadline.bold().monospacedDigit())
                }

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    inspectorLabel("7-day trend")
                    IdentityTrendLabel(trend: seniorityTrend)
                }
            }

            Text(
                "Observed change over the retained local history. This is a direction, not daily accrual or a reward estimate."
            )
            .font(.caption2)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Label(chainEvidenceSource, systemImage: "checkmark.circle.fill")
                Text("·")
                Text(chainEvidenceKind)
                Spacer(minLength: 4)
                PrivacyProtectedText(
                    value: chainEvidenceAt.map(IdentityFreshnessFormatter.string) ?? "Pending",
                    field: chainEvidenceAt == nil ? nil : .localTimestamp,
                    mask: .compact
                )
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private var provenance: some View {
        VStack(alignment: .leading, spacing: 9) {
            inspectorLabel(role.kind == .seniority ? "Historical identity evidence" : "Evidence")
            inspectorValueRow(
                title: "Source",
                value: role.evidenceSource,
                symbol: "checkmark.circle.fill"
            )
            inspectorValueRow(
                title: "Kind",
                value: role.evidenceKind,
                symbol: "doc.text.magnifyingglass"
            )
            HStack {
                Text("Last verification")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                Spacer()
                PrivacyProtectedText(
                    value: role.observedAt.map(IdentityFreshnessFormatter.string) ?? "Pending",
                    field: role.observedAt == nil ? nil : .localTimestamp,
                    mask: .compact
                )
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(role.observedAt == nil ? theme.colors.warning : theme.colors.success)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspectorLabel("Actions")
            HStack(spacing: 7) {
                Button("Copy identifier", systemImage: "doc.on.doc") {
                    onCopy(role.value)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!role.isAvailable)

                if role.externalURL != nil {
                    Button("Open", systemImage: "arrow.up.right.square") {
                        onOpen(role.externalURL)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!role.isAvailable)
                    .help("Open this public identity on Quilscan")
                }
            }
            .controlSize(.small)
        }
    }

    private var custodyBoundary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Local-only boundary", systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.success)
            Text(
                "This screen receives public identifiers only. Private key bytes are never read, displayed, copied, or transmitted by the dashboard."
            )
            .font(.caption2)
            .foregroundStyle(theme.colors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            theme.colors.success.opacity(0.065),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func inspectorLabel(_ value: String) -> some View {
        Text(value.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.55)
            .foregroundStyle(theme.colors.secondaryText)
    }

    private func inspectorValueRow(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.colors.success)
                .frame(width: 14)
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}
