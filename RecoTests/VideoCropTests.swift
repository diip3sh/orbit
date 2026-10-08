//
//  VideoCropTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct VideoCropTests {

    private let video = CGSize(width: 1601, height: 1200)

    @Test func nothingCroppedIsTheWholeVideoWhateverItsSize() {
        #expect(VideoCrop.pixels(of: VideoCrop.full, in: video) == CGRect(origin: .zero, size: video))
    }

    @Test func aCropIsOnWholePixelsWithEvenSides() {
        let pixels = VideoCrop.pixels(of: CGRect(x: 0.1, y: 0.25, width: 0.333, height: 0.5), in: video)
        #expect(pixels == CGRect(x: 160, y: 300, width: 532, height: 600))
    }

    @Test func aCropStaysInsideTheVideoAndKeepsTheMinimumSize() {
        #expect(VideoCrop.clamped(CGRect(x: 0.95, y: -0.2, width: 0.01, height: 0.5)) == CGRect(x: 0.9, y: 0, width: 0.1, height: 0.5))
    }

    @Test func draggingAnEdgeStopsAtTheVideoAndAtTheMinimumSize() {
        let crop = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        let widened = VideoCrop.dragged(crop, edges: .left, by: CGSize(width: -0.5, height: 0))
        #expect(widened.minX == 0)
        #expect(abs(widened.maxX - 0.7) < 1e-9)
        #expect(abs(widened.minY - 0.2) < 1e-9 && abs(widened.height - 0.5) < 1e-9)
        let narrowed = VideoCrop.dragged(crop, edges: [.right, .bottom], by: CGSize(width: -0.6, height: 0.1))
        #expect(abs(narrowed.width - VideoCrop.minimumSize) < 1e-9)
        #expect(abs(narrowed.maxY - 0.8) < 1e-9)
        #expect(narrowed.minX == 0.2)
    }

    @Test func draggingInsideMovesTheCropWholeAndKeepsItInTheVideo() {
        let crop = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        #expect(VideoCrop.dragged(crop, edges: .all, by: CGSize(width: 0.5, height: -0.1)) == CGRect(x: 0.5, y: 0.1, width: 0.5, height: 0.5))
    }

    @Test func croppedTelemetryPlacesPositionsInTheCrop() throws {
        let screen = CGRect(x: 0, y: 0, width: 800, height: 600)
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: CGSize(width: 1600, height: 1200)), keystrokesAvailable: false)
        telemetry.geometry = [.init(time: 0, screenRect: screen, contentRect: screen, contentScale: 1, scaleFactor: 2)]

        let cropped = telemetry.cropped(to: CGRect(x: 400, y: 200, width: 800, height: 600))

        let geometry = try #require(cropped.geometry(at: 0))
        // (300, 200) pt is (600, 400) px in the video, (200, 200) px in the crop
        #expect(InputTelemetry.videoPixel(for: CGPoint(x: 300, y: 200), geometry: geometry) == CGPoint(x: 200, y: 200))
        #expect(cropped.normalizedVideoPoint(for: CGPoint(x: 300, y: 200), at: 0) == CGPoint(x: 0.25, y: 1.0 / 3))
        // Left of the crop is outside it
        #expect((cropped.normalizedVideoPoint(for: CGPoint(x: 100, y: 200), at: 0)?.x ?? 0) < 0)
    }
}
