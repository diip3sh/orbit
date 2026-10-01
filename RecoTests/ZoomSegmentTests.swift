//
//  ZoomSegmentTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation
import Testing
@testable import Reco

struct ZoomSegmentTests {

    /// Automatic zooms at 2..<4 and 6..<8 in a 10 s recording.
    private let zooms = [
        ZoomSegment(range: 2..<4, focus: .followCursor, isAutomatic: true),
        ZoomSegment(range: 6..<8, focus: .followCursor, isAutomatic: true)
    ]

    @Test func clampsTheCentreSoTheViewStaysInsideTheFrame() {
        #expect(ZoomSegment.clamped(CGPoint(x: 0.1, y: 0.9), scale: 2) == CGPoint(x: 0.25, y: 0.75))
        #expect(ZoomSegment.clamped(CGPoint(x: 0.4, y: 0.6), scale: 2) == CGPoint(x: 0.4, y: 0.6))
        #expect(ZoomSegment.clamped(CGPoint(x: 0.1, y: 0.9), scale: 1) == CGPoint(x: 0.5, y: 0.5))
    }

    @Test func aNewZoomLastsTheDefaultOrUpToWhatFollows() throws {
        #expect(try #require(zooms.newZoom(at: 8, focus: .followCursor, duration: 10)).range == 8..<10)
        #expect(try #require(zooms.newZoom(at: 4.5, focus: .followCursor, duration: 10)).range == 4.5..<6)
        #expect(try #require(zooms.newZoom(at: 0, focus: .followCursor, duration: 10)).range == 0..<2)
        #expect(zooms.newZoom(at: 0, focus: .followCursor, duration: 10)?.isAutomatic == false)
    }

    @Test func noZoomStartsInsideAnotherOrWithoutRoom() {
        #expect(zooms.newZoom(at: 3, focus: .followCursor, duration: 10) == nil)
        #expect(zooms.newZoom(at: 5.75, focus: .followCursor, duration: 10) == nil)
        #expect(zooms.newZoom(at: 9.8, focus: .followCursor, duration: 10) == nil)
    }

    @Test func insertsInTimeOrder() {
        let zoom = ZoomSegment(range: 4.5..<5.5, focus: .followCursor)

        #expect(zooms.inserting(zoom).map(\.range) == [2..<4, 4.5..<5.5, 6..<8])
    }

    @Test func movingStopsAtTheNeighboursAndTheEnds() {
        #expect(zooms.moving(zooms[0].id, by: 1, duration: 10).map(\.range) == [3..<5, 6..<8])
        #expect(zooms.moving(zooms[0].id, by: 3, duration: 10).map(\.range) == [4..<6, 6..<8])
        #expect(zooms.moving(zooms[0].id, by: -5, duration: 10).map(\.range) == [0..<2, 6..<8])
        #expect(zooms.moving(zooms[1].id, by: 5, duration: 10).map(\.range) == [2..<4, 8..<10])
    }

    @Test func resizingStopsAtTheNeighboursAndKeepsTheMinimum() {
        #expect(zooms.movingStart(of: zooms[1].id, to: 1).map(\.range) == [2..<4, 4..<8])
        #expect(zooms.movingStart(of: zooms[1].id, to: 9).map(\.range) == [2..<4, 7.5..<8])
        #expect(zooms.movingEnd(of: zooms[0].id, to: 9, duration: 10).map(\.range) == [2..<6, 6..<8])
        #expect(zooms.movingEnd(of: zooms[1].id, to: 12, duration: 10).map(\.range) == [2..<4, 6..<10])
        #expect(zooms.movingEnd(of: zooms[0].id, to: 0, duration: 10).map(\.range) == [2..<2.5, 6..<8])
    }

    @Test func aChangedZoomBecomesManual() {
        var zoom = zooms[1]
        zoom.scale = 3

        #expect(zooms.replacing(zoom).map(\.isAutomatic) == [true, false])
        #expect(zooms.replacing(zoom)[1].scale == 3)
        #expect(zooms.moving(zooms[0].id, by: 1, duration: 10).map(\.isAutomatic) == [false, true])
        #expect(zooms.movingEnd(of: zooms[0].id, to: 5, duration: 10).map(\.isAutomatic) == [false, true])
    }

    @Test func removesById() {
        #expect(zooms.removing(zooms[0].id) == [zooms[1]])
    }

    @Test func regeneratingReplacesAutomaticZoomsAndKeepsManualOnes() {
        let manual = zooms.replacing(zooms[1])
        let generated = [
            ZoomSegment(range: 0..<1, focus: .followCursor, isAutomatic: true),
            ZoomSegment(range: 5..<7, focus: .followCursor, isAutomatic: true),
            ZoomSegment(range: 8..<9, focus: .followCursor, isAutomatic: true)
        ]

        let regenerated = manual.regenerated(with: generated)

        // The one overlapping the manual zoom is left out
        #expect(regenerated.map(\.range) == [0..<1, 6..<8, 8..<9])
        #expect(regenerated.map(\.isAutomatic) == [true, false, true])
    }

    @Test func fixingTheFocusCentresItAndKeepsTheViewInside() {
        var zoom = zooms[0]
        #expect(zoom.fixedCenter == nil)

        zoom.followsCursor = false
        #expect(zoom.fixedCenter == CGPoint(x: 0.5, y: 0.5))
        zoom.fixedCenter = CGPoint(x: 0, y: 1)
        #expect(zoom.focus == .fixed(center: CGPoint(x: 0.25, y: 0.75)))
        zoom.followsCursor = true
        #expect(zoom.focus == .followCursor)
    }
}
