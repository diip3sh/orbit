//
//  LibraryDateRailTests.swift
//  RecoTests
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Reco

/// The rail's one subtle rule, which nothing else catches: the marked date's line grows leftward from a
/// shared right edge, so the lines read as one column; and at rest only the lines are drawn, the titles
/// waiting for the pointer.
///
/// `ImageRenderer` draws the rail because it holds no glass, no AppKit control and no `ScrollView`.
/// Colours aren't asserted: the rail uses the system's, so which of two is brighter depends on the
/// appearance the test host happens to be in. Hover can't be rendered, so the title chip isn't covered.
@MainActor
struct LibraryDateRailTests {

    private func group(_ title: String) -> LibraryDateGroup {
        LibraryDateGroup(title: title, items: [LibraryItem(url: URL(filePath: "/r/\(title).png"), kind: .screenshot, date: .now)])
    }

    /// The rail with its second date marked, drawn at 1×.
    private func rendered() throws -> ImagePixels {
        let rail = LibraryDateRail(groups: [group("Today"), group("September 2026")], active: "September 2026") { _ in }
        let renderer = ImageRenderer(content: rail)
        renderer.scale = 1
        return ImagePixels(try #require(renderer.cgImage))
    }

    @Test func onlyLinesAreDrawnAndTheMarkedOneIsLonger() throws {
        let image = try rendered()
        #expect(image.width == Int(LibraryDateRail.width), "the rail takes only its lines' room: \(image.width)")

        // Across the whole rail, so a title drawn at rest would show as more or wider bands
        let bands = image.bands(inColumns: 0..<image.width)
        #expect(bands.count == 2, "one line per date and nothing else")

        let today = try #require(bands.first)
        let september = try #require(bands.last)
        #expect(today.rows.count <= 3 && september.rows.count <= 3, "lines, not text: \(today.rows) and \(september.rows)")
        // The markers share a right edge and grow leftward, so they read as one column rather than
        // each starting where its line happens to
        #expect(today.right == september.right, "the markers end together: \(today.right) against \(september.right)")
        #expect(september.width - today.width >= 8, "the marked line is longer: \(september.width) against \(today.width)")
        #expect(september.rows.lowerBound - today.rows.upperBound <= 12, "the lines sit close: \(today.rows) then \(september.rows)")
    }
}

/// A rendered view's pixels, read from its top-left corner.
private struct ImagePixels {

    /// One date's line: the rows it covers and its leftmost and rightmost pixels.
    struct Band {
        let rows: ClosedRange<Int>
        let left: Int
        let right: Int

        var width: Int { right - left + 1 }
    }

    private let data: [UInt8]
    let width: Int
    private let height: Int

    init(_ image: CGImage) {
        let imageWidth = image.width
        let imageHeight = image.height
        var pixels = [UInt8](repeating: 0, count: imageWidth * imageHeight * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGColorSpace(name: CGColorSpace.sRGB).flatMap {
                CGContext(
                    data: buffer.baseAddress, width: imageWidth, height: imageHeight, bitsPerComponent: 8, bytesPerRow: imageWidth * 4,
                    space: $0, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            }
            context?.draw(image, in: CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        }
        width = imageWidth
        height = imageHeight
        data = pixels
    }

    /// Whether the pixel at `column`, `row` from the top-left is drawn at all.
    private func isDrawn(column: Int, row: Int) -> Bool {
        guard column >= 0, column < width, row >= 0, row < height else { return false }
        // A bitmap context's first row is the image's top one, though its drawing origin is bottom-left
        return data[(row * width + column) * 4 + 3] > 8
    }

    /// The runs of rows that have any drawn pixel in `columns`, each with its horizontal extent. Only
    /// one thing is drawn per row there, so each run is one line.
    func bands(inColumns columns: Range<Int>) -> [Band] {
        var bands: [Band] = []
        for row in 0..<height {
            let drawn = columns.filter { isDrawn(column: $0, row: row) }
            guard let left = drawn.first, let right = drawn.last else { continue }
            if let last = bands.last, last.rows.upperBound == row - 1 {
                bands[bands.count - 1] = Band(rows: last.rows.lowerBound...row, left: min(last.left, left), right: max(last.right, right))
            } else {
                bands.append(Band(rows: row...row, left: left, right: right))
            }
        }
        return bands
    }
}
