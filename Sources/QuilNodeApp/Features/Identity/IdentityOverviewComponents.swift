import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ChainSeniorityFact: View {
    @Environment(\.quilTheme) private var theme

    let snapshot: NodeSnapshot
    let trend: SeniorityTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Chain seniority")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Consensus registry · local view")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 10)
                PrivacyProtectedText(
                    value: snapshot.seniority > 0
                        ? snapshot.seniority.formatted(.number.grouping(.automatic))
                        : "Reading…",
                    field: .seniority
                )
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            HStack(spacing: 6) {
                Image(systemName: trendSystemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(trendTint)
                Text("7-day trend")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                PrivacyProtectedText(
                    value: trendValue,
                    field: trend.direction != .collecting ? .seniority : nil,
                    mask: .compact
                )
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(trendTint)
                Spacer(minLength: 4)
                if let observedAt = trend.latestObservedAt ?? snapshot.seniorityUpdatedAt {
                    Text(observationLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    PrivacyProtectedText(
                        value: relativeTime(from: observedAt),
                        field: .localTimestamp,
                        mask: .compact
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private var trendValue: String {
        switch trend.direction {
        case .collecting:
            return "Collecting"
        case .increased:
            return "Up +\(trend.delta.formatted(.number.grouping(.automatic)))"
        case .unchanged:
            return "No change observed"
        case .decreased:
            return "Down \(trend.delta.formatted(.number.grouping(.automatic)))"
        }
    }

    private var trendSystemImage: String {
        switch trend.direction {
        case .collecting: "ellipsis"
        case .increased: "arrow.up.right"
        case .unchanged: "minus"
        case .decreased: "arrow.down.right"
        }
    }

    private var trendTint: Color {
        switch trend.direction {
        case .collecting: theme.colors.secondaryText
        case .increased: theme.colors.success
        case .unchanged: theme.colors.info
        case .decreased: theme.colors.warning
        }
    }

    private var observationLabel: String {
        snapshot.seniorityEvidenceKind == .valueChanged ? "Changed" : "Observed"
    }

    private var accessibilitySummary: String {
        "Chain seniority trend: \(trendValue). \(observationLabel) \(trend.latestObservedAt.map(relativeTime) ?? "time unavailable")."
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct LocalIdentitySourceBadge: View {
    let title: String

    var body: some View {
        Label(title, systemImage: "lock.shield.fill")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Source: \(title.lowercased())")
    }
}

struct IdentityStatusPill: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 0.7))
    }
}

/// Allocation counts are rendered in one place so Identity can never protect
/// the headline while accidentally leaking the same number in supporting copy.
struct IdentityAllocationFact: View {
    @Environment(\.quilTheme) private var theme
    let snapshot: NodeSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(tint).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text("Shard work").font(.caption).foregroundStyle(.secondary)
                PrivacyProtectedPhrase(
                    value: String(snapshot.totalAllocations),
                    suffix: " total allocations",
                    field: .allocationCount
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            allocationSummary
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    @ViewBuilder
    private var allocationSummary: some View {
        let active = snapshot.activeShards
        let joining = snapshot.pendingJoins
        if active > 0 && joining > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                PrivacyProtectedText(value: String(active), field: .activeShardCount)
                Text(" active · ")
                PrivacyProtectedText(value: String(joining), field: .allocationCount)
                Text(" joining")
            }
            .accessibilityElement(children: .combine)
        } else if active > 0 {
            PrivacyProtectedPhrase(
                value: String(active),
                suffix: " active",
                field: .activeShardCount
            )
        } else if joining > 0 {
            PrivacyProtectedPhrase(
                value: String(joining),
                suffix: " joining",
                field: .allocationCount
            )
        } else if snapshot.totalAllocations > 0 {
            PrivacyProtectedPhrase(
                value: String(snapshot.totalAllocations),
                suffix: " waiting",
                field: .allocationCount
            )
        } else {
            Text("None")
        }
    }

    private var tint: Color {
        snapshot.activeShards > 0 ? theme.colors.success : theme.colors.warning
    }
}

struct PublicIdentityRow: View {
    let label: String
    let detail: String
    let value: String?
    let systemImage: String
    var externalURL: URL? = nil

    private var displayedValue: String { value ?? "Not available" }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.callout.weight(.medium))
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 178, alignment: .leading)

            PrivacyProtectedText(
                value: displayedValue,
                field: value != nil ? .networkIdentifier : nil
            )
            .font(.callout.monospaced())
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)

            Spacer(minLength: 8)

            if let value {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .help("Copy \(label.lowercased())")
                .accessibilityLabel("Copy \(label.lowercased())")
            }

            if let externalURL, value != nil {
                Button {
                    NSWorkspace.shared.open(externalURL)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .help("Open \(label.lowercased()) on Quilscan")
                .accessibilityLabel("Open \(label.lowercased()) on Quilscan")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
    }
}

enum IdentityExplorerLink {
    static func peer(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        return URL(string: "https://quilscan.com/peer")?.appendingPathComponent(value)
    }

    static func prover(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        var components = URLComponents(string: "https://quilscan.com/rings")
        components?.queryItems = [URLQueryItem(name: "prover", value: value)]
        return components?.url
    }
}
