//
//  ClickMarkerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Testing
@testable import Reco

struct ClickMarkerTests {

    private let markers = [1, 2, 2.2].map { ClickMarker(time: $0, position: .zero, diameter: 10) }

    private func active(at time: Double) -> [Double] {
        ClickMarker.active(in: markers, at: time, duration: 0.5).map(\.time)
    }

    @Test func aRingShowsFromItsPressForItsDuration() {
        #expect(active(at: 0.9).isEmpty)
        #expect(active(at: 1) == [1])
        #expect(active(at: 1.49) == [1])
        #expect(active(at: 1.5).isEmpty)
    }

    @Test func ringsOfClicksInQuickSuccessionOverlap() {
        #expect(active(at: 2.3) == [2, 2.2])
        #expect(active(at: 2.5) == [2.2])
    }
}
