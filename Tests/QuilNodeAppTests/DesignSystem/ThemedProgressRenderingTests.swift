import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp

final class ThemedProgressRenderingTests: XCTestCase {
    @MainActor
    func testDeterminateTrackUsesItsColorAndFractionWhenInactive() throws {
        let renderer = ImageRenderer(
            content:
                ProgressView(value: 0.25)
                .progressViewStyle(QuilLinearProgressStyle(tint: .red))
                .frame(width: 200)
                .background(Color.white)
                .environment(\.controlActiveState, .inactive)
                .quilThemed(.classicLight)
        )
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(image.height, 8)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let filled = try XCTUnwrap(bitmap.colorAt(x: 20, y: 4)?.usingColorSpace(.sRGB))
        let empty = try XCTUnwrap(bitmap.colorAt(x: 100, y: 4)?.usingColorSpace(.sRGB))
        XCTAssertGreaterThan(filled.redComponent - filled.greenComponent, 0.5)
        XCTAssertLessThan(abs(empty.redComponent - empty.greenComponent), 0.15)
    }
}
