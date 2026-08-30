import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct ActiveRecoveryIdentityCard: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var walletManager: WalletManager
    let keyset: ManagedKeyset

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 15) {
                ZStack {
                    ThemeAccentShape(shape: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE IDENTITY PACKAGE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(theme.colors.secondaryText)
                    HStack(spacing: 8) {
                        PrivacyProtectedText(
                            value: keyset.name,
                            field: .recoveryMetadata,
                            mask: .identifier
                        )
                        .font(.title2.bold())
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(theme.colors.success)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(theme.colors.success.opacity(0.12), in: Capsule())
                    }
                    Text("This complete keyset is installed in the running node.")
                        .font(.caption)
                        .foregroundStyle(theme.colors.secondaryText)
                }
                Spacer()
                if !keyset.isManaged {
                    Button("Protect this identity") {
                        Task { await walletManager.adoptActive() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(walletManager.isWorking)
                }
            }

            Divider()
            HStack(spacing: 12) {
                RecoveryPackageFact(
                    title: "FORMAT",
                    value: keyset.format.label,
                    systemImage: "shippingbox.fill",
                    privacyField: nil
                )
                RecoveryPackageFact(
                    title: "CUSTODY",
                    value: keyset.isManaged ? "Managed locally" : "Protection required",
                    systemImage: keyset.isManaged ? "lock.shield.fill" : "exclamationmark.shield.fill",
                    privacyField: nil
                )
                RecoveryPackageFact(
                    title: "LAST ACTIVATED",
                    value: keyset.lastActivatedAt.map {
                        $0.formatted(date: .abbreviated, time: .shortened)
                    } ?? "Current node",
                    systemImage: "clock.arrow.circlepath",
                    privacyField: keyset.lastActivatedAt != nil ? .localTimestamp : nil
                )
            }

            DisclosureGroup("Technical package details") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Package fingerprint").foregroundStyle(theme.colors.secondaryText)
                        Spacer()
                        PrivacyProtectedText(
                            value: keyset.fingerprint,
                            field: .recoveryMetadata,
                            mask: .identifier
                        )
                        .font(.caption.monospaced())
                    }
                    HStack(alignment: .top) {
                        Text("Key store").foregroundStyle(theme.colors.secondaryText)
                        Spacer()
                        PrivacyProtectedText(
                            value: "\(keyset.keyCount) entries · \(keyset.keyTypes.joined(separator: ", "))",
                            field: .recoveryMetadata
                        )
                        .font(.caption.monospaced())
                        .multilineTextAlignment(.trailing)
                        .textSelection(.enabled)
                    }
                    HStack {
                        Text("Origin").foregroundStyle(theme.colors.secondaryText)
                        Spacer()
                        PrivacyProtectedText(value: keyset.sourceLabel, field: .recoveryMetadata)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .font(.caption)
                .padding(.top, 8)
            }
            .font(.caption.weight(.semibold))

            if keyset.requiresMigration {
                Label(
                    "This legacy keyset will be migrated only by the installed official .25 node during activation. The original pair is backed up first and retained for rollback.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.caption)
                .foregroundStyle(theme.colors.warning)
                .padding(10)
                .background(theme.colors.warning.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .controlSurface(tint: theme.colors.accent)
    }
}

struct IdentityLibraryRow: View {
    @Environment(\.quilTheme) private var theme
    let keyset: ManagedKeyset
    let onActivate: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DashboardCircleIcon(
                systemImage: keyset.isActive ? "checkmark.seal.fill" : "person.crop.circle",
                tint: keyset.isActive ? theme.colors.success : theme.colors.accent,
                size: 38
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    PrivacyProtectedText(
                        value: keyset.name,
                        field: .recoveryMetadata,
                        mask: .identifier
                    )
                    .font(.subheadline.weight(.semibold))
                    if keyset.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.colors.success)
                    }
                    if keyset.requiresMigration {
                        Text("MIGRATES ON ACTIVATION").font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.colors.warning)
                    }
                }
                Text("\(keyset.format.label) · \(keyset.sourceLabel)")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Button("Export copy", action: onExport)
                .buttonStyle(.bordered)
                .accessibilityLabel("Export recovery copy")
            if !keyset.isActive {
                Button("Switch to this", action: onActivate)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Switch node identity")
            }
        }
        .padding(11)
        .background(
            theme.colors.surfaceElevated.opacity(0.65),
            in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius))
    }
}

struct RecoveryPackageFact: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let systemImage: String
    let privacyField: PrivacyField?

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.colors.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            theme.colors.surfaceElevated.opacity(0.65),
            in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
        )
    }
}

struct RecoveryCopyState: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        HStack(spacing: 11) {
            DashboardCircleIcon(systemImage: systemImage, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(theme.colors.secondaryText)
                PrivacyProtectedText(value: value, field: privacyField)
                    .font(.subheadline.weight(.semibold))
                Text(detail).font(.caption2).foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(
            theme.colors.surfaceElevated.opacity(0.62),
            in: RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius)
        )
    }
}

struct RecoveryExplanation: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption.weight(.semibold))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
