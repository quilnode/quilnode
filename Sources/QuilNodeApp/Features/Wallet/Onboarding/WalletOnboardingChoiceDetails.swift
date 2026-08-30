import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct KeepIdentityDetails: View {
    @Environment(\.quilTheme) private var theme
    let identity: ManagedKeyset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                OnboardingEvidenceRow(
                    systemImage: "doc.badge.gearshape",
                    title: "Format: \(identity.format.label)",
                    detail: formatDetail
                )
                OnboardingEvidenceRow(
                    systemImage: "clock.badge.checkmark",
                    title: "Seniority root preserved",
                    detail: "Legacy Ed448 identity continuity remains part of the complete keyset."
                )
                OnboardingEvidenceRow(
                    systemImage: "checkmark.arrow.trianglehead.counterclockwise",
                    title: "Validation & rollback",
                    detail: "If a required activation fails validation, the previous pair is restored."
                )
                OnboardingEvidenceRow(
                    systemImage: "arrow.clockwise.circle",
                    title: "Restart only if required",
                    detail:
                        "Adopting the active pair is non-disruptive; switching identities requires a validated restart."
                )
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "externaldrive.badge.checkmark")
                    .foregroundStyle(theme.colors.warning)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recovery copy before management").font(.caption.weight(.semibold))
                    Text("The root-protected service creates and hash-verifies a complete local rollback copy first.")
                        .font(.caption2)
                        .foregroundStyle(theme.colors.secondaryText)
                }
            }
            .padding(9)
            .background(theme.colors.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        }
    }

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    private var formatDetail: String {
        identity.requiresMigration
            ? "The official current node performs the necessary migration after the pre-migration backup."
            : "This format is already supported by the installed runtime."
    }
}

struct ImportIdentityDetails: View {
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            alignment: .leading,
            spacing: 12
        ) {
            OnboardingEvidenceRow(
                systemImage: "folder.badge.questionmark",
                title: "Automatic format detection",
                detail: "The local service recognizes complete legacy, transitional, and current keysets."
            )
            OnboardingEvidenceRow(
                systemImage: "key.horizontal.fill",
                title: "Complete package required",
                detail: "config.yml and keys.yml stay together so seniority and current identities are not split."
            )
            OnboardingEvidenceRow(
                systemImage: "checkmark.shield.fill",
                title: "Validate before activation",
                detail: "Ownership, file type, size, names, links, and package health are checked locally."
            )
            OnboardingEvidenceRow(
                systemImage: "arrow.uturn.backward.circle.fill",
                title: "Recover on failure",
                detail: "Activation preserves stores and restores the previous identity if health validation fails."
            )
        }
    }
}

struct CreateIdentityDetails: View {
    @Environment(\.quilTheme) private var theme
    @Binding var name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingEvidenceRow(
                systemImage: "checkmark.seal.fill",
                title: "Verified local generation",
                detail:
                    "The separately managed qclient and installed node generate and validate the complete current keyset."
            )
            VStack(alignment: .leading, spacing: 6) {
                OnboardingSectionLabel(text: "Local identity label")
                TextField("Identity name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Local identity label")
                Text("This label is stored locally for your own organization; it is not published to the network.")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
            }
        }
    }
}
