//
//  TimelineRulerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Testing
@testable import Reco

@MainActor
struct TimelineRulerTests {

    @Test func picksTheFinestScaleWhoseLabelsDontTouch() {
        // 10 points a second: 5 s labels would be 50 points apart, 10 s ones 100
        #expect(TimelineRuler.scale(duration: 60, width: 600) == (10, 2))
        // 266 points a second
        #expect(TimelineRuler.scale(duration: 3, width: 800) == (0.5, 0.1))
        // A 10-minute recording on 800 points: 1.3 points a second
        #expect(TimelineRuler.scale(duration: 600, width: 800) == (60, 10))
    }

    @Test func longRecordingsUseTheCoarsestScale() {
        #expect(TimelineRuler.scale(duration: 10 * 3600, width: 800) == (3600, 600))
    }

    @Test func labelsCarryTheirUnitsAndTenthsOnlyWhenUnderASecondApart() {
        #expect(TimelineRuler.label(for: 0, major: 0.5) == "0s")
        #expect(TimelineRuler.label(for: 1.5, major: 0.5) == "1.5s")
        #expect(TimelineRuler.label(for: 1, major: 0.5) == "1s")
        #expect(TimelineRuler.label(for: 5, major: 5) == "5s")
        #expect(TimelineRuler.label(for: 90, major: 30) == "1m 30s")
        #expect(TimelineRuler.label(for: 120, major: 60) == "2m")
        #expect(TimelineRuler.label(for: 5400, major: 1800) == "1h 30m")
    }
}
