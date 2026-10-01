//
//  TimelineMarkersTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreGraphics
import Testing
@testable import Reco

struct TimelineMarkersTests {

    private var telemetry: InputTelemetry {
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: CGSize(width: 100, height: 100)), keystrokesAvailable: true)
        telemetry.clicks = [
            .init(time: 1, location: .zero, button: .left, isDown: true, clickCount: 1),
            .init(time: 1.1, location: .zero, button: .left, isDown: false, clickCount: 1),
            .init(time: 4, location: .zero, button: .right, isDown: true, clickCount: 1),
            .init(time: 7, location: .zero, button: .left, isDown: true, clickCount: 1)
        ]
        telemetry.keys = [
            .init(time: 2, keyCode: 0, modifiers: [], isRepeat: false),
            .init(time: 2.5, keyCode: 0, modifiers: [], isRepeat: true),
            .init(time: 8, keyCode: 1, modifiers: [], isRepeat: false)
        ]
        return telemetry
    }

    @Test func marksPressesButNotReleasesOrRepeats() {
        let markers = TimelineMarkers(telemetry: telemetry)

        #expect(markers.clicks == [1, 4, 7])
        #expect(markers.keys == [2, 8])
    }
}
