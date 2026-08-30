import Foundation
import SwiftUI

/// Central policy and persistence for privacy-aware presentation.
///
/// The node model always retains its real local values. Privacy Mode changes
/// presentation only, so monitoring and alerts continue working normally.
enum PrivacyMode {
    static let defaultsKey = "privacyModeEnabled"
}

/// Fixed visual density for redacted collections.
///
/// Masking text is not enough when one rendered row still corresponds to one
/// private item. Privacy-aware collection views use this constant instead of
/// their model count, so layout cannot reveal worker or allocation cardinality.
enum PrivacyLayoutPolicy {
    static let collectionPlaceholderCount = 3
}

/// The single privacy vocabulary used by every dashboard surface.
///
/// A field is classified by what it reveals, not by where it happens to be
/// rendered. This keeps the dashboard, menu bar, recovery views, and future
/// themes consistent. New sensitive values must choose a case here before
/// they can be displayed with `PrivacyProtectedText`.
enum PrivacyField: String, CaseIterable {
    case activeShardCount
    case allocationCount
    case shardAllocation
    case seniority
    case quilBalance
    case nodeUptime
    case hardwareProfile
    case networkIdentifier
    case networkPort
    case networkActivity
    case recoveryMetadata
    case localTimestamp

    var mask: PrivacyMaskStyle {
        switch self {
        case .activeShardCount, .allocationCount, .hardwareProfile, .networkActivity:
            .compact
        case .networkIdentifier, .shardAllocation:
            .identifier
        case .networkPort, .seniority, .quilBalance, .nodeUptime, .recoveryMetadata, .localTimestamp:
            .standard
        }
    }

    var accessibilityName: String {
        switch self {
        case .activeShardCount: "Active shard count"
        case .allocationCount: "Allocation count"
        case .shardAllocation: "Shard allocation"
        case .seniority: "Seniority"
        case .quilBalance: "QUIL balance"
        case .nodeUptime: "Node uptime"
        case .hardwareProfile: "Hardware detail"
        case .networkIdentifier: "Network identifier"
        case .networkPort: "Network port"
        case .networkActivity: "Network activity"
        case .recoveryMetadata: "Recovery detail"
        case .localTimestamp: "Local timestamp"
        }
    }
}

/// A small vocabulary of familiar, non-semantic masks. Fixed lengths avoid
/// disclosing the magnitude or exact character count of the hidden value.
enum PrivacyMaskStyle {
    case compact
    case standard
    case identifier

    var text: String {
        switch self {
        case .compact: "***"
        case .standard: "*****"
        case .identifier: "**********"
        }
    }
}

/// Displays the real value normally and a familiar asterisk mask whenever the
/// nearest container applies the `.privacy` redaction reason. The real value
/// remains in the local model, so adjacent copy and navigation actions keep
/// working without placing the secret text in the visible or accessibility UI.
struct PrivacyProtectedText: View {
    @Environment(\.redactionReasons) private var redactionReasons

    let value: String
    let field: PrivacyField?
    var mask: PrivacyMaskStyle? = nil

    private var isHidden: Bool {
        field != nil && redactionReasons.contains(.privacy)
    }

    @ViewBuilder
    var body: some View {
        Group {
            if isHidden {
                Text((mask ?? field?.mask ?? .standard).text)
                    .tracking(1.0)
                    .opacity(0.68)
                    .accessibilityLabel("\(field?.accessibilityName ?? "Sensitive value") hidden")
                    .help("Hidden by Privacy Mode — use the eye control to reveal")
            } else {
                Text(value)
                    .accessibilityLabel(value)
            }
        }
    }
}

/// Editable counterpart to `PrivacyProtectedText`.
///
/// Privacy Mode keeps the binding live and editable but substitutes Apple's
/// secure entry presentation. A deliberate, local reveal action restores the
/// ordinary field temporarily; disabling and re-enabling Privacy Mode always
/// returns it to the protected state.
struct PrivacyProtectedTextField: View {
    @Environment(\.quilMotion) private var motion
    @Environment(\.redactionReasons) private var redactionReasons

    let title: String
    @Binding var text: String
    let field: PrivacyField
    @State private var isRevealed = false

    private var isPrivacyModeActive: Bool {
        redactionReasons.contains(.privacy)
    }

    private var isProtected: Bool {
        isPrivacyModeActive && !isRevealed
    }

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if isProtected {
                    Text(field.mask.text)
                        .tracking(1.0)
                        .opacity(0.68)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(Color(nsColor: .separatorColor).opacity(0.75), lineWidth: 0.7)
                                }
                        )
                        .accessibilityLabel("\(field.accessibilityName) hidden")
                        .help("Hidden by Privacy Mode — reveal to edit or copy")
                } else {
                    TextField(title, text: $text)
                        .accessibilityLabel(title)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if isPrivacyModeActive {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .frame(width: 18, height: 18)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(motion.symbol, value: isRevealed)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isRevealed
                        ? "Hide \(field.accessibilityName.lowercased())"
                        : "Reveal \(field.accessibilityName.lowercased())"
                )
                .help(isRevealed ? "Hide this value" : "Reveal this value temporarily")
            }
        }
        .onChange(of: isPrivacyModeActive) { _, active in
            if active { isRevealed = false }
        }
    }
}

/// Keeps sentence context visible while protecting only its classified value.
/// Use this instead of interpolating sensitive counts into a `Text` string.
struct PrivacyProtectedPhrase: View {
    var prefix = ""
    let value: String
    var suffix = ""
    let field: PrivacyField
    var mask: PrivacyMaskStyle? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if !prefix.isEmpty { Text(prefix) }
            PrivacyProtectedText(value: value, field: field, mask: mask)
                .monospacedDigit()
            if !suffix.isEmpty { Text(suffix) }
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
final class PrivacyModeController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: PrivacyMode.defaultsKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: PrivacyMode.defaultsKey)
    }

    func toggle() {
        isEnabled.toggle()
    }
}

struct PrivacyModeButton: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @Binding var isEnabled: Bool
    var compact = false
    var fillsWidth = false
    var controlHeight: CGFloat = 30
    var embedded = false

    var body: some View {
        Button {
            isEnabled.toggle()
        } label: {
            HStack(spacing: compact ? 0 : 10) {
                Image(systemName: isEnabled ? "eye.slash.fill" : "eye")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(width: compact ? 40 : 24)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(motion.symbol, value: isEnabled)
                if !compact {
                    Text("Privacy")
                        .foregroundStyle(theme.colors.primaryText)
                    Spacer(minLength: 4)
                    Text(isEnabled ? "Hidden" : "Visible")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isEnabled ? theme.colors.privacy : theme.colors.secondaryText)
                    Circle()
                        .fill(isEnabled ? theme.colors.privacy : theme.colors.secondaryText.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(
                isEnabled
                    ? (embedded ? theme.colors.privacy : Color.white)
                    : theme.colors.primaryText.opacity(0.78)
            )
            .padding(.horizontal, compact ? 0 : 9)
            .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: fillsWidth ? .leading : .center)
            .frame(width: compact && !fillsWidth ? controlHeight : nil, height: controlHeight)
            .background {
                if !embedded {
                    RoundedRectangle(
                        cornerRadius: fillsWidth ? theme.metrics.controlCornerRadius : controlHeight / 2,
                        style: .continuous
                    )
                    .fill(isEnabled ? theme.colors.privacy : theme.colors.surfaceElevated)
                } else if compact && isEnabled {
                    Circle().fill(theme.colors.privacy.opacity(0.16)).padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .accessibilityLabel("Privacy Mode")
        .accessibilityValue(isEnabled ? "On, sensitive values hidden" : "Off, sensitive values visible")
        .accessibilityHint(
            isEnabled
                ? "Shows sensitive local and operational values"
                : "Masks sensitive local and operational values throughout QuilNode"
        )
        .accessibilityIdentifier("quilnode-privacy-mode-button")
        .help(isEnabled ? "Show sensitive local values" : "Mask sensitive local values throughout QuilNode")
    }
}
