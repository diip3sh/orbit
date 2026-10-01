//
//  CursorShapeTrackTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Reco

@MainActor
struct CursorShapeTrackTests {

    private func shapes(_ entries: [(time: Double, sprite: Int)]) -> [InputTelemetry.CursorShape] {
        entries.map { InputTelemetry.CursorShape(time: $0.time, sprite: $0.sprite) }
    }

    /// A 20×30 px image of 10×15 pt, with its hot spot 2 pt right of and 3 pt below its top-left corner.
    private func sprite(id: Int) -> InputTelemetry.CursorSprite {
        .drawn(pixels: CGSize(width: 20, height: 30), size: CGSize(width: 10, height: 15), hotspot: CGPoint(x: 2, y: 3), id: id) { context in
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 30))
        }
    }

    @Test func dropsShapesShownOnlyBriefly() {
        // An I-beam for 50 ms while crossing a text field, then a hand, and one for 100 ms at the end
        let shapes = shapes([(0, 0), (1, 1), (1.05, 0), (2, 2), (4.9, 3)])

        let steady = CursorShapeTrack.steadyShapes(shapes, duration: 5)

        #expect(steady == self.shapes([(0, 0), (2, 2)]))
    }

    @Test func keepsTheFirstShapeWhenAllAreBrief() {
        #expect(CursorShapeTrack.steadyShapes(shapes([(0, 0)]), duration: 0.1) == shapes([(0, 0)]))
    }

    @Test func showsEachShapeWithItsHotspotInPixels() throws {
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: CGSize(width: 100, height: 100), cursorInVideo: false), keystrokesAvailable: false)
        telemetry.cursorSprites = [sprite(id: 0), sprite(id: 7)]
        telemetry.cursorShapes = shapes([(0, 7), (1, 0)])

        let track = CursorShapeTrack(telemetry: telemetry, duration: 5, arrow: nil)

        let first = try #require(track.sprite(at: 0.5))
        #expect(first.image.extent.size == CGSize(width: 20, height: 30))
        #expect(first.pointsPerPixel == 0.5)
        // 2 pt from the left and 3 pt from the top of a 30 px image, at 2 px per point
        #expect(first.hotspot == CGPoint(x: 4, y: 24))
        #expect(track.sprite(at: 2) != nil)
    }

    @Test func drawsAnArrowWhenThereAreNoShapes() throws {
        // Version 2 files have none, nor do recordings where the system didn't say which cursor showed
        let version2 = try JSONDecoder().decode(InputTelemetry.self, from: Fixture.data("telemetry-v2"))
        let arrow = StandardCursors.arrowSprite

        let sprite = try #require(CursorShapeTrack(telemetry: version2, duration: 5, arrow: arrow).sprite(at: 1))

        #expect(sprite.image.extent.width / arrow.size.width >= 2)
        #expect(sprite.pointsPerPixel == arrow.size.width / sprite.image.extent.width)
        #expect(CursorShapeTrack(telemetry: version2, duration: 5, arrow: nil).sprite(at: 1) == nil)
    }

    @Test func drawsAnArrowWhenNoImageCanBeRead() throws {
        // The fixture's images aren't PNGs
        let telemetry = try JSONDecoder().decode(InputTelemetry.self, from: Fixture.data("telemetry-v3"))

        #expect(CursorShapeTrack(telemetry: telemetry, duration: 5, arrow: sprite(id: 0)).sprite(at: 1)?.hotspot == CGPoint(x: 4, y: 24))
    }
}
