//
//  PageChangesTests.swift
//  RecoTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

struct PageChangesTests {

    private func zoom(_ range: Range<Double>) -> ZoomSegment {
        ZoomSegment(range: range, focus: .fixed(center: CGPoint(x: 0.5, y: 0.5)))
    }

    @Test func aScrollStartsAfterAPauseAndAPageWhenItCommits() {
        var telemetry = InputTelemetry(capture: .init(kind: .web, videoSize: CGSize(width: 1440, height: 900)), keystrokesAvailable: true)
        // Two scrolls a frame apart each, and a page a click opened in between
        telemetry.scrolls = [1.0, 1.0167, 1.0333, 3.0, 3.0167].map { .init(time: $0, location: .zero, delta: CGVector(dx: 0, dy: -10)) }
        telemetry.navigations = [.init(time: 2.0, url: "https://example.com/plan")]

        #expect(PageChanges.times(in: telemetry) == [1.0, 2.0, 3.0])
    }

    @Test func aZoomEndsShortlyAfterTheFirstChangeInIt() {
        let zooms = PageChanges.ending([zoom(1..<4), zoom(5..<6)], at: [0.5, 2, 3])

        #expect(zooms.map(\.range) == [1..<2.3, 5..<6])
    }

    @Test func aZoomTheLastChangeIsAfterIsKept() {
        #expect(PageChanges.ending([zoom(1..<2)], at: [2, 5]).map(\.range) == [1..<2])
    }

    @Test func aZoomTheChangeComesUnderWithinTheLeadTimeIsDropped() {
        #expect(PageChanges.ending([zoom(1..<4)], at: [1]).isEmpty)
        #expect(PageChanges.ending([zoom(1..<4)], at: [1.49]).isEmpty)
        #expect(PageChanges.ending([zoom(1..<4)], at: [1.5]).map(\.range) == [1..<1.8])
    }
}
