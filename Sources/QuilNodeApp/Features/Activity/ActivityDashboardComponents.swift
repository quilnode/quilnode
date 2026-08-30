import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ActivityIntervalPoint: Identifiable {
    let timestamp: Date
    let framesPerMinute: Double
    let peers: Int
    var id: Date { timestamp }
}

struct ActivitySectionHeader: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.colors.secondaryText)
            .padding(.horizontal, 4)
    }
}

struct ActivitySummaryCard: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    var privacyField: PrivacyField? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.secondaryText)
            }
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
        .controlSurface(tint: tint)
    }
}

struct ActivityEventRow: View {
    @Environment(\.quilTheme) private var theme
    let event: NodeActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    PrivacyProtectedText(
                        value: event.timestamp.formatted(date: .abbreviated, time: .shortened),
                        field: .localTimestamp
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
                }
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                if let value = event.sensitiveValue {
                    PrivacyProtectedText(value: value, field: privacyField)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint)
                }
            }
        }
        .padding(13)
    }

    private var privacyField: PrivacyField {
        switch event.category {
        case .proving: .allocationCount
        case .network: .networkActivity
        case .identity: .seniority
        case .rewards: .quilBalance
        case .runtime: .localTimestamp
        }
    }

    private var tint: Color {
        switch event.category {
        case .runtime: theme.colors.info
        case .proving: theme.colors.success
        case .network: theme.colors.accentSecondary
        case .rewards: theme.colors.wallet
        case .identity: theme.colors.accent
        }
    }

    private var icon: String {
        switch event.category {
        case .runtime: "power"
        case .proving: "square.grid.3x3.fill"
        case .network: "network"
        case .rewards: "sparkles"
        case .identity: "person.text.rectangle.fill"
        }
    }
}

struct ActivityEmptyState: View {
    @Environment(\.quilTheme) private var theme
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.colors.info)
                .frame(width: 34, height: 34)
                .background(theme.colors.info.opacity(0.11), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
        }
        .padding(16)
    }
}
