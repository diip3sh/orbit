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

    @Test func labelsShowTenthsOnlyWhenLabelsAreUnderASecondApart() {
        #expect(TimelineRuler.label(for: 5, major: 5) == "0:05")
        #expect(TimelineRuler.label(for: 90, major: 30) == "1:30")
        #expect(TimelineRuler.label(for: 1.5, major: 0.5) == "0:01.5")
        #expect(TimelineRuler.label(for: 3600, major: 600) == "1:00:00")
    }
}
