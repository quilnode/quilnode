import SwiftUI

enum ProtocolAllocationPlaceholderMode: Hashable {
    case loading
    case privacy
}

/// A fixed-density replacement for worker and allocation cards before live
/// telemetry arrives and while Privacy Mode is active. It deliberately reuses
/// the live card geometry without using any real record count or state.
struct ProtocolAllocationPlaceholderLayout: View {
    @Environment(\.quilTheme) private var theme

    let mode: ProtocolAllocationPlaceholderMode

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: PrivacyLayoutPolicy.collectionPlaceholderCount
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<PrivacyLayoutPolicy.collectionPlaceholderCount, id: \.self) { _ in
                HStack(alignment: .top, spacing: 9) {
                    leadingIndicator
                    VStack(alignment: .leading, spacing: 2) {
                        placeholderTitle
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(theme.colors.primaryText)
                        placeholderDetail
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(theme.colors.secondaryText)
                            .lineLimit(1)
                        placeholderMetadata
                            .font(.system(size: 8.7, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.colors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 0)
                }
                .protocolAllocationCardSurface(
                    theme: theme,
                    borderColor: tint.opacity(0.60),
                    emphasized: mode == .privacy
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .help(helpText)
    }

    @ViewBuilder
    private var leadingIndicator: some View {
        if mode == .loading {
            ProgressView()
                .controlSize(.small)
                .tint(theme.colors.info)
                .frame(width: 8, height: 8)
                .padding(.top, 2)
        } else {
            Circle()
                .fill(theme.colors.privacy)
                .frame(width: 8, height: 8)
                .padding(.top, 3)
        }
    }

    @ViewBuilder
    private var placeholderTitle: some View {
        if mode == .loading {
            Text("Worker —")
        } else {
            maskedPhrase(label: "Worker", mask: .compact)
        }
    }

    @ViewBuilder
    private var placeholderDetail: some View {
        if mode == .loading {
            Text("Shard —")
        } else {
            maskedPhrase(label: "Shard", mask: .identifier)
        }
    }

    @ViewBuilder
    private var placeholderMetadata: some View {
        if mode == .loading {
            Text("Coverage — · — provers · Ring —")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Coverage ")
                Text(PrivacyMaskStyle.identifier.text)
                Text(" · ")
                Text(PrivacyMaskStyle.compact.text)
                Text(" provers · Ring ")
                Text(PrivacyMaskStyle.compact.text)
            }
        }
    }

    private func maskedPhrase(label: String, mask: PrivacyMaskStyle) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(label) ")
            Text(mask.text)
                .tracking(1)
        }
    }

    private var tint: Color {
        mode == .loading ? theme.colors.info : theme.colors.privacy
    }

    private var accessibilityLabel: String {
        switch mode {
        case .loading:
            "Loading worker, shard assignment, and coverage telemetry."
        case .privacy:
            "Worker and allocation layout hidden by Privacy Mode. The three placeholders are decorative and do not reveal a count."
        }
    }

    private var helpText: String {
        mode == .loading
            ? "Loading local allocation telemetry"
            : "Fixed privacy placeholder — does not represent the worker or allocation count"
    }
}
