import AppKit
import SwiftUI
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class AllocationEpochRenderingTests: XCTestCase {
    /// Exercises the real card at the grid's minimum width, with synthetic data
    /// only. Set QUILNODE_EPOCH_REVIEW_IMAGE to capture the same render for review.
    @MainActor
    func testEpochCardsRenderAtMinimumGridWidth() throws {
        let clock = NodeEpochClock(frame: 1000, epochLength: 720)
        let allocations: [ShardAllocation] = [
            .init(index: 0, filter: "aabbccdd", status: "joining", worker: "1", confirmFrame: 800),
            .init(index: 1, filter: "eeff0011", status: "active", worker: "2", registeredEpoch: 3),
            .init(index: 2, filter: "22334455", status: "re-confirm!", worker: "3", registeredEpoch: 0),
        ]
        let content = VStack(spacing: 12) {
            ForEach([false, true], id: \.self) { isPrivate in
                HStack(alignment: .top, spacing: 12) {
                    ForEach(allocations) { allocation in
                        ProtocolAllocationCell(allocation: allocation, clock: clock)
                            .frame(width: 210)
                            .redacted(reason: isPrivate ? .privacy : [])
                    }
                }
            }
        }
        .padding(20)
        .background(QuilTheme.quilNode.colors.canvas)
        .quilThemed(.quilNode)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(image.width, (210 * 3 + 12 * 2 + 40) * 2)
        XCTAssertGreaterThan(image.height, 200)
        XCTAssertLessThan(image.height, 800)

        if let path = ProcessInfo.processInfo.environment["QUILNODE_EPOCH_REVIEW_IMAGE"] {
            let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
