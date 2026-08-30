import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct AuthorizationExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var installer: InstallationCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                DashboardCircleIcon(systemImage: "lock.shield.fill", tint: theme.colors.accent, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("One macOS authorization").font(.title2.bold())
                    Text("You will see the standard administrator password prompt next.")
                        .font(.subheadline).foregroundStyle(theme.colors.secondaryText)
                }
            }

            Text("Why it is needed")
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                AuthorizationScopeRow(text: "Create the restricted, non-login _quilnode service account")
                AuthorizationScopeRow(
                    text: "Install two fixed launchd services and the verified node under /opt/quilibrium/node")
                AuthorizationScopeRow(text: "Apply Quilibrium's required file-descriptor limits")
                AuthorizationScopeRow(
                    text:
                        "Authorize this exact code-signed QuilNode app to request a small fixed set of local operations"
                )
            }

            VStack(alignment: .leading, spacing: 7) {
                Label("What QuilNode does not do", systemImage: "hand.raised.fill")
                    .font(.headline).foregroundStyle(theme.colors.success)
                Text(
                    "Your password is handled only by macOS and is never visible to QuilNode. The app receives no reusable credential. The interface never opens, copies, displays, modifies, or transmits private-key bytes. Key import and recovery are validated by the local service, and no remote command channel exists."
                )
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .controlSurface(tint: theme.colors.success)

            HStack {
                Button("Not now") { dismiss() }
                Spacer()
                Button("Continue to macOS password") {
                    dismiss()
                    Task { await installer.authorizeAndInstall() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(26)
        .frame(width: 620)
    }
}

struct InstallCheckRow: View {
    let check: InstallationCheck
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title).font(.caption.weight(.semibold))
                Text(check.detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    private var icon: String {
        switch check.state {
        case .pass: "checkmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .blocked: "xmark.octagon.fill"
        case .notRequired: "minus.circle.fill"
        }
    }
    private var color: Color {
        switch check.state {
        case .pass: .green
        case .warning: .orange
        case .blocked: .red
        case .notRequired: .secondary
        }
    }
}

struct AuthorizationScopeRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            Text(text).font(.subheadline)
        }
    }
}
