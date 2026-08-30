import SwiftUI

struct RecoveryOperationNotice: View {
    @Environment(\.quilTheme) private var theme
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(
                    "The signed local service is performing this operation. Keep QuilNode open until validation completes."
                )
                .font(.caption2)
                .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer()
        }
        .padding(12)
        .controlSurface(tint: theme.colors.info)
        .accessibilityLabel("\(title) in progress")
    }
}

struct RecoveryServiceNotice: View {
    @Environment(\.quilTheme) private var theme
    let detail: String
    let requiresAuthorization: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DashboardCircleIcon(
                systemImage: requiresAuthorization ? "lock.rotation" : "exclamationmark.triangle.fill",
                tint: theme.colors.warning,
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(requiresAuthorization ? "Secure service update required" : "Recovery status unavailable")
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            if requiresAuthorization {
                Button("Review & authorize", action: action)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Try again", action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(13)
        .controlSurface(tint: theme.colors.warning)
        .accessibilityElement(children: .contain)
    }
}

struct RecoveryResultNotice: View {
    @Environment(\.quilTheme) private var theme
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.colors.success)
            Text(message)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(11)
        .controlSurface(tint: theme.colors.success)
        .accessibilityLabel("Identity Recovery status: \(message)")
    }
}

struct RecoveryLoadingView: View {
    var body: some View {
        VStack(spacing: 11) {
            ProgressView().controlSize(.large)
            Text("Checking the active identity package…")
                .font(.headline)
            Text("Reading public inventory metadata from the signed local service.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .controlSurface()
        .accessibilityLabel("Checking the active identity package")
    }
}

struct RecoveryEmptyState: View {
    @Environment(\.quilTheme) private var theme
    let create: () -> Void
    let importPackage: () -> Void

    var body: some View {
        VStack(spacing: 13) {
            DashboardCircleIcon(
                systemImage: "person.crop.circle.badge.questionmark",
                tint: theme.colors.accent,
                size: 52
            )
            Text("No complete node identity found")
                .font(.title3.bold())
            Text("Create a fresh identity or import the folder containing the complete config.yml and keys.yml pair.")
                .font(.subheadline)
                .foregroundStyle(theme.colors.secondaryText)
                .multilineTextAlignment(.center)
            HStack {
                Button("Create identity", action: create)
                    .buttonStyle(.borderedProminent)
                Button("Import package", action: importPackage)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .controlSurface()
    }
}
