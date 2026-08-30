import SwiftUI

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
