//
//  RecordingPausesTests.swift
//  RecoTests
//
//  Created by Diip3sh on 25.09.26.
//

import CoreMedia
import Testing
@testable import Reco

struct RecordingPausesTests {

    @Test func samplesKeepTheirTimingWithoutPauses() {
        #expect(RecordingPauses().pausedTime(start: time(1), end: time(2)) == .zero)
    }

    @Test func samplesOverlappingThePauseInProgressAreDropped() {
        var pauses = RecordingPauses()
        pauses.pause(at: time(10))

        #expect(pauses.pausedTime(start: time(9), end: time(10)) == .zero)
        #expect(pauses.pausedTime(start: time(9.99), end: time(10.01)) == nil)
        #expect(pauses.pausedTime(start: time(12), end: time(12)) == nil)
    }

    @Test func samplesAfterAResumeAreShiftedByThePausedTime() {
        var pauses = RecordingPauses()
        pauses.pause(at: time(10))
        pauses.resume(at: time(15))

        // Straddling the resume, or captured during the pause and delivered late
        #expect(pauses.pausedTime(start: time(14.99), end: time(15.01)) == nil)
        #expect(pauses.pausedTime(start: time(12), end: time(12)) == nil)
        #expect(pauses.pausedTime(start: time(15), end: time(15.02)) == time(5))
    }

    @Test func pausesAccumulate() {
        var pauses = RecordingPauses()
        pauses.pause(at: time(10))
        pauses.resume(at: time(15))
        pauses.pause(at: time(20))
        pauses.resume(at: time(22))

        #expect(pauses.pausedTime(start: time(23), end: time(23)) == time(7))
        #expect(pauses.intervals == [10..<15, 20..<22])
    }

    @Test func thePauseInProgressEndsAtInfinity() {
        var pauses = RecordingPauses()
        pauses.pause(at: time(10))
        pauses.resume(at: time(15))
        pauses.pause(at: time(20))

        #expect(pauses.intervals == [10..<15, 20..<Double.infinity])
    }

    @Test func repeatedPauseAndResumeCallsAreIgnored() {
        var pauses = RecordingPauses()
        pauses.resume(at: time(5))
        pauses.pause(at: time(10))
        pauses.pause(at: time(12))
        pauses.resume(at: time(15))
        pauses.resume(at: time(20))

        #expect(pauses.intervals == [10..<15])
    }

    private func time(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }
}
