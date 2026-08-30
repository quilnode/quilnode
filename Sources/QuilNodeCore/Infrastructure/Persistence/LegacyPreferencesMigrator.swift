import Foundation

/// One-time, non-destructive migration from QuilNode's pre-public bundle ID.
///
/// UserDefaults contains presentation and workflow preferences only. This
/// migrator deliberately copies an allowlist; it never enumerates application
/// support, keysets, node configuration, stores, logs, or credentials. The old
/// domain remains intact so the reversible app-bundle rollback is useful.
public enum LegacyPreferencesMigrator {
    public static let legacyBundleIdentifier = "local.quilnode.operator"
    public static let permanentBundleIdentifier = "com.quilnode.app"
    public static let completionKey = "migration.legacyBundleIdentifier.v1"

    private static let exactKeys: Set<String> = [
        "walletOnboardingCompleted",
        "networkSetup.initialGuideCompleted.v1",
        "networkSetup.remindLaterAt.v1",
        "networkSetup.activePortProfile.v1",
        "privacyModeEnabled",
        "selectedQuilThemeID",
        "selectedQuilThemeAppearance",
        "node-update-policy",
        "node-update-last-check",
        "node-update-phase-timings-v1",
        "dashboardSidebarCollapsed",
        "settings.selectedPane",
    ]
    private static let allowedPrefixes = [
        "node-update-approved-marker-",
        "local-alert-last-sent.",
    ]

    public static func migrateIfNeeded(
        defaults: UserDefaults = .standard,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) {
        guard bundleIdentifier == permanentBundleIdentifier,
            defaults.bool(forKey: completionKey) == false,
            let legacy = defaults.persistentDomain(forName: legacyBundleIdentifier)
        else { return }

        for (key, value) in legacy where isAllowed(key) {
            // A value deliberately chosen in the permanent app always wins.
            guard defaults.object(forKey: key) == nil else { continue }
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: completionKey)
    }

    public static func isAllowed(_ key: String) -> Bool {
        exactKeys.contains(key) || allowedPrefixes.contains(where: key.hasPrefix)
    }
}
