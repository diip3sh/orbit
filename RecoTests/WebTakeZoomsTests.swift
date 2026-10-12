//
//  WebTakeZoomsTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct WebTakeZoomsTests {

    private let viewport = CGSize(width: 1000, height: 500)

    @Test func framesTheShownElementWithRoomAroundIt() {
        var zooms = WebTakeZooms(viewport: viewport)

        zooms.show(CGRect(x: 600, y: 100, width: 200, height: 200), during: 1..<3)
        let segments = zooms.segments(endingAt: [])

        let zoom = segments.first
        #expect(segments.count == 1)
        #expect(zoom?.range == 1..<3)
        // The 200 px height fills 80% of the 500 px view: 2×, under the width's 4×
        #expect(zoom?.scale == 2)
        #expect(zoom?.fixedCenter == CGPoint(x: 0.7, y: 0.4))
        #expect(zoom?.isAutomatic == false)
    }

    @Test func magnifiesAtMostThreeTimesAndCentresInsideTheFrame() {
        var zooms = WebTakeZooms(viewport: viewport)

        zooms.show(CGRect(x: 0, y: 0, width: 20, height: 20), during: 0..<1)

        let zoom = zooms.segments(endingAt: []).first
        #expect(zoom?.scale == WebTakeZooms.maximumScale)
        #expect(zoom?.fixedCenter == ZoomSegment.clamped(CGPoint(x: 0.01, y: 0.02), scale: 3))
    }

    @Test func anElementNearlyAsBigAsTheViewMakesNoZoom() {
        var zooms = WebTakeZooms(viewport: viewport)

        zooms.show(CGRect(x: 0, y: 0, width: 1000, height: 400), during: 0..<2)

        #expect(zooms.segments(endingAt: []).isEmpty)
    }

    @Test func anElementMissingOrMostlyOutOfViewCantBeFramedAndAHalfVisibleOneIsByItsVisibleHalf() {
        var zooms = WebTakeZooms(viewport: viewport)

        #expect(!WebTakeZooms.canFrame(nil, in: viewport))
        #expect(!WebTakeZooms.canFrame(CGRect(x: 100, y: 400, width: 100, height: 300), in: viewport))
        #expect(!WebTakeZooms.canFrame(CGRect(x: 100, y: 100, width: 0, height: 100), in: viewport))
        let half = CGRect(x: 100, y: 400, width: 100, height: 200)
        #expect(WebTakeZooms.canFrame(half, in: viewport))
        zooms.show(half, during: 0..<1)

        let zoom = zooms.segments(endingAt: []).first
        #expect(zoom?.scale == 3)
        #expect(zoom?.fixedCenter == ZoomSegment.clamped(CGPoint(x: 0.15, y: 0.9), scale: 3))
    }

    @Test func endsAsThePageScrollsAndPansToTheNextZoom() {
        var zooms = WebTakeZooms(viewport: viewport)
        let configuration = AutoZoomGenerator.Configuration()

        zooms.show(CGRect(x: 0, y: 0, width: 100, height: 100), during: 1..<4)
        zooms.show(CGRect(x: 500, y: 0, width: 100, height: 100), during: 4.5..<6)
        zooms.show(CGRect(x: 500, y: 300, width: 100, height: 100), during: 8..<9)

        // The scroll at 2 s ends the first zoom shortly after; the second is close enough to pan to; the third isn't
        let segments = zooms.segments(endingAt: [2, 7])
        #expect(segments.map(\.range) == [1..<(2 + configuration.scrollHold), 4.5..<6, 8..<9])
    }

    @Test func aZoomThePageChangesUnderBeforeItIsInIsLeftOut() {
        var zooms = WebTakeZooms(viewport: viewport)
        let leadTime = AutoZoomGenerator.Configuration().leadTime

        // A click that opens a page: the page changes a frame after the clip starts
        zooms.show(CGRect(x: 0, y: 0, width: 100, height: 100), during: 1..<3)
        zooms.show(CGRect(x: 0, y: 0, width: 100, height: 100), during: 5..<7)

        #expect(zooms.segments(endingAt: [1.1, 5 + leadTime]).map(\.range) == [5..<(5 + leadTime + 0.3)])
    }
}
