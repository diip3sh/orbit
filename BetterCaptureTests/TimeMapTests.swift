//
//  TimeMapTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import Testing
@testable import BetterCapture

struct TimeMapTests {

    @Test func isTheIdentityWithoutCuts() {
        let map = TimeMap(cuts: [], sourceDuration: 10)

        #expect(map.outputDuration == 10)
        for time in [0, 2.5, 9.75] {
            #expect(map.outputTime(atSource: time) == time)
            #expect(map.sourceTime(atOutput: time) == time)
        }
    }

    @Test func aCutRemovesItsRangeAndShiftsLaterTimes() {
        let map = TimeMap(cuts: [2..<5], sourceDuration: 10)

        #expect(map.outputDuration == 7)
        #expect(map.outputTime(atSource: 1) == 1)
        #expect(map.outputTime(atSource: 3) == nil)
        #expect(map.outputTime(atSource: 6) == 3)
        #expect(map.sourceTime(atOutput: 3) == 6)
    }

    @Test func sourceTimeClampsToTheOutput() {
        let map = TimeMap(cuts: [8..<10], sourceDuration: 10)

        #expect(map.sourceTime(atOutput: -1) == 0)
        #expect(map.sourceTime(atOutput: 20) == 8)
    }
}
