import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp

final class RecoveryThemeRenderingTests: XCTestCase {
    /// Real recovery controls with synthetic state only; no identity files or
    /// services are opened by these opt-in visual captures.
    @MainActor
    func testRecoveryThemeReviewCaptures() async throws {
        guard let directory = ProcessInfo.processInfo.environment["QUILNODE_THEME_REVIEW_DIRECTORY"] else {
            throw XCTSkip("Set QUILNODE_THEME_REVIEW_DIRECTORY for native visual review.")
        }
        let suiteName = "QuilNode.RecoveryThemeReview.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let privacy = PrivacyModeController(defaults: defaults)
        privacy.isEnabled = true
        let stages: [RecoveryLayerPresentation] = [
            .init(
                layer: .activePackage, state: .verified, value: "Available",
                detail: "Complete package is available.", privacyField: nil),
            .init(
                layer: .automaticRollback, state: .review, value: "Review copy",
                detail: "Check rollback coverage.", privacyField: nil),
            .init(
                layer: .separateBackup, state: .recommended, value: "Export a backup",
                detail: "Keep a separate copy under your control.", privacyField: nil),
        ]
        for theme in QuilTheme.builtIns {
            let content = RecoveryRunwayView(stages: stages)
                .padding(16)
                .background(theme.colors.canvas)
                .environmentObject(privacy)
                .quilThemed(theme)
            let host = NSHostingView(rootView: content)
            let bounds = NSRect(x: 0, y: 0, width: 360, height: 440)
            let window = NSWindow(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            window.contentView = host
            host.frame = bounds
            window.orderFront(nil)
            try await Task.sleep(for: .milliseconds(150))
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try png.write(
                to: URL(fileURLWithPath: directory).appendingPathComponent("\(theme.id)-recovery.png"),
                options: .atomic
            )
        }
    }
}
