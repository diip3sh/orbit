//
//  PropertyTrackTests.swift
//  RecoTests
//

import Testing
@testable import Reco

struct PropertyTrackTests {

    @Test func holdsTheEndsAndEasesBetween() throws {
        // Given out of order: tracks sort their keyframes
        let track = try #require(PropertyTrack(.positionX, keyframes: [
            Keyframe(time: 2, value: 300),
            Keyframe(time: 1, value: 100, easing: .cubicBezier(0.42, 0, 1, 1))
        ]))

        #expect(track.value(at: 0) == 100)
        #expect(track.value(at: 1) == 100)
        #expect(abs(track.value(at: 1.5) - (100 + 200 * 0.3153)) < 0.2)
        #expect(track.value(at: 2) == 300)
        #expect(track.value(at: 9) == 300)
    }

    @Test func scaleMovesInLogSpace() throws {
        let track = try #require(PropertyTrack(.scale, keyframes: [Keyframe(time: 0, value: 1), Keyframe(time: 1, value: 4)]))

        #expect(abs(track.value(at: 0.5) - 2) < 1e-9)
    }

    @Test func noKeyframesIsNoTrack() {
        #expect(PropertyTrack(.opacity, keyframes: []) == nil)
    }
}
