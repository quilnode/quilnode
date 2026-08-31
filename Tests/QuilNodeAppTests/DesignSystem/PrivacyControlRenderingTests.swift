import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp

final class PrivacyControlRenderingTests: XCTestCase {
    @MainActor
    func testPrivacyControlKeepsOneRowAtNarrowSidebarWidths() throws {
        for theme in [QuilTheme.classic, .classicLight, .quilNode, .quilNodeLight] {
            for width in [128.0, 162.0, 176.0] {
                for enabled in [false, true] {
                    let renderer = ImageRenderer(
                        content: control(theme: theme, width: width, enabled: enabled)
                    )
                    let image = try XCTUnwrap(renderer.cgImage)
                    XCTAssertEqual(image.width, Int(width))
                    XCTAssertEqual(image.height, 44)
                }
            }
        }
    }

    @MainActor
    func testPrivacyControlReviewSheet() throws {
        let themes = [QuilTheme.classic, .classicLight, .quilNode, .quilNodeLight]
        let renderer = ImageRenderer(
            content: VStack(spacing: 12) {
                ForEach(themes) { theme in
                    HStack(spacing: 12) {
                        ForEach([128.0, 162.0, 176.0], id: \.self) { width in
                            VStack(spacing: 4) {
                                self.control(theme: theme, width: width, enabled: true)
                                self.control(theme: theme, width: width, enabled: false)
                            }
                        }
                    }
                }
            }.padding(20).background(Color.gray))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        if let path = ProcessInfo.processInfo.environment["QUILNODE_PRIVACY_REVIEW_IMAGE"] {
            let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @MainActor
    private func control(theme: QuilTheme, width: Double, enabled: Bool) -> some View {
        PrivacyModeButton(isEnabled: .constant(enabled), fillsWidth: true, controlHeight: 44, embedded: true)
            .frame(width: width)
            .background(theme.colors.surfaceElevated)
            .quilThemed(theme)
    }
}
