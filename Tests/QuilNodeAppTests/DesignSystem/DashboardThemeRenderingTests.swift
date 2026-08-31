import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class DashboardThemeRenderingTests: XCTestCase {
    /// Opt-in native captures of the real dashboard. No app scene or service
    /// coordinator is started; telemetry and preferences are isolated fixtures.
    @MainActor
    func testDashboardThemeReviewCaptures() async throws {
        guard let directory = ProcessInfo.processInfo.environment["QUILNODE_THEME_REVIEW_DIRECTORY"] else {
            throw XCTSkip("Set QUILNODE_THEME_REVIEW_DIRECTORY for native visual review.")
        }
        let suiteName = "QuilNode.ThemeReview.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(false, forKey: "dashboardSidebarCollapsed")
        let privacy = PrivacyModeController(defaults: defaults)
        privacy.isEnabled = true
        let monitor = NodeMonitor(previewSnapshot: Self.snapshot)
        let releaseChecker = ReleaseChecker(preview: ())
        let installation = InstallationCoordinator()
        let network = NetworkReadinessCoordinator()
        let commands = DashboardCommandCenter()
        let visibility = ProtocolMilestoneVisibilityStore()
        let wallet = WalletManager(defaults: defaults)
        let images = try registerBrandImages()
        defer { images.forEach { $0.setName(nil) } }

        for theme in [QuilTheme.classic, .classicLight, .quilNode, .quilNodeLight] {
            let themes = ThemeController(previewTheme: theme)
            for width in [820.0, 980.0, 1416.0] {
                let content = DashboardView()
                    .environmentObject(monitor)
                    .environmentObject(privacy)
                    .environmentObject(releaseChecker)
                    .environmentObject(installation)
                    .environmentObject(network)
                    .environmentObject(commands)
                    .environmentObject(visibility)
                    .environmentObject(themes)
                    .environmentObject(wallet)
                    .defaultAppStorage(defaults)
                    .environment(\.controlActiveState, .key)
                    .quilThemed(theme)
                let host = NSHostingView(rootView: content)
                let size = NSSize(width: width, height: 909)
                let window = NSWindow(
                    contentRect: NSRect(origin: .zero, size: size),
                    styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                defer { window.close() }
                window.contentView = host
                host.frame = NSRect(origin: .zero, size: size)
                window.orderFront(nil)
                try await Task.sleep(for: .milliseconds(150))
                host.layoutSubtreeIfNeeded()
                host.displayIfNeeded()
                let scrollView = try XCTUnwrap(findScrollView(in: host))
                let document = try XCTUnwrap(scrollView.documentView)
                XCTAssertLessThanOrEqual(document.bounds.width, scrollView.contentSize.width + 1, theme.id)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                let file = URL(fileURLWithPath: directory).appendingPathComponent("\(theme.id)-\(Int(width)).png")
                try png.write(to: file, options: .atomic)
                XCTAssertEqual(Int(host.bounds.width), Int(width))
                if width == 820 {
                    document.scroll(NSPoint(x: 0, y: max(0, document.bounds.height - scrollView.contentSize.height)))
                    try await Task.sleep(for: .milliseconds(50))
                    host.displayIfNeeded()
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let bottom = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try bottom.write(
                        to: URL(fileURLWithPath: directory).appendingPathComponent("\(theme.id)-820-bottom.png"),
                        options: .atomic
                    )
                }
            }
        }
    }

    @MainActor
    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { self.findScrollView(in: $0) }.first
    }

    @MainActor
    private func registerBrandImages() throws -> [NSImage] {
        // SwiftPM does not compile the Xcode asset catalog. Register its actual
        // SVG sources in this test process; do not substitute placeholder marks.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try ["Network", "Nodes", "Core", "Q"].map { layer in
            let name = "QuilNodeBrand\(layer)"
            let url = root.appendingPathComponent("Resources/Assets.xcassets/\(name).imageset/\(name).svg")
            let image = try XCTUnwrap(NSImage(contentsOf: url))
            XCTAssertTrue(image.setName(name))
            return image
        }
    }

    private static var snapshot: NodeSnapshot {
        NodeSnapshot(
            collectedAt: Date(), isRunning: true, version: "2.1.0.25",
            quilBalance: "125.5", seniority: 5_270_690, reachable: true,
            lastReceivedFrame: 775_520, lastGlobalHeadFrame: 775_520,
            epoch: 1_077, epochLength: 720, nextEpochFrame: 776_160,
            frame: 775_520, peers: 240, archivePeers: 6, archiveEndpointCount: 6, pendingJoins: 3,
            activeShards: 4, totalAllocations: 7,
            cpuPercent: 18, cpuCoreEquivalent: 1.8, memoryMB: 2_300, processUptime: "08:22:10",
            logLastModifiedAt: Date(), metricsUpdatedAt: Date(), frameLastAdvancedAt: Date(),
            framesPerMinute: 5.2, lowerFramesPerMinute: 4.8, upperFramesPerMinute: 5.6
        )
    }
}
