import SwiftUI

struct IdentityTransactionTimeline: View {
    @Environment(\.quilTheme) private var theme

    let moments: [IdentityTransactionMoment]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: moment.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(index == 1 ? theme.colors.accent : theme.colors.success)
                        .frame(width: 26, height: 26)
                        .background(
                            (index == 1 ? theme.colors.accent : theme.colors.success).opacity(0.09),
                            in: Circle()
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(moment.title).font(.caption.weight(.semibold))
                        Text(moment.detail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)

                if index < moments.count - 1 {
                    Divider().frame(height: 42)
                }
            }
        }
        .padding(.vertical, 8)
        .controlSurface(tint: theme.colors.info)
    }
}

struct IdentityDispositionPicker: View {
    @Environment(\.quilTheme) private var theme

    @Binding var selection: IdentityImportDisposition

    var body: some View {
        HStack(spacing: 10) {
            choice(
                .activate,
                title: "Activate after import",
                detail: "Import, protect, switch, and verify in one confirmed sequence.",
                symbol: "bolt.fill",
                badge: "Recommended"
            )
            choice(
                .recoveryOnly,
                title: "Add to recovery only",
                detail: "Store the verified package for a later protected switch.",
                symbol: "archivebox.fill",
                badge: nil
            )
        }
    }

    private func choice(
        _ value: IdentityImportDisposition,
        title: String,
        detail: String,
        symbol: String,
        badge: String?
    ) -> some View {
        Button {
            selection = value
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selection == value ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selection == value ? theme.colors.accent : theme.colors.secondaryText)
                DashboardCircleIcon(
                    systemImage: symbol,
                    tint: selection == value ? theme.colors.accent : theme.colors.secondaryText,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.caption.weight(.semibold))
                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .tracking(0.45)
                                .foregroundStyle(theme.colors.accent)
                        }
                    }
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .frame(maxWidth: .infinity)
        .background(theme.colors.surface.opacity(selection == value ? 0.88 : 0.52))
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    selection == value ? theme.colors.accent.opacity(0.86) : theme.colors.border.opacity(0.44),
                    lineWidth: selection == value ? 1.2 : 0.6
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous))
        .quilHoverSurface(tint: theme.colors.accent, cornerRadius: theme.metrics.controlCornerRadius)
    }
}
