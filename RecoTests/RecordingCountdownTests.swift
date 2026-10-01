//
//  RecordingCountdownTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Testing
@testable import Reco

@MainActor
struct RecordingCountdownTests {

    @Test func countsDownOncePerSecondThenFinishes() async {
        let probe = CountdownProbe()
        await probe.countdown.start(seconds: 3) { probe.finished = true }.value

        #expect(probe.ticks == [3, 2, 1])
        #expect(probe.finished)
        #expect(probe.countdown.isRunning == false)
    }

    @Test func cancellingStopsBeforeFinishing() async {
        let probe = CountdownProbe(cancelOnTick: 2)
        await probe.countdown.start(seconds: 3) { probe.finished = true }.value

        #expect(probe.ticks == [3, 2])
        #expect(probe.finished == false)
        #expect(probe.countdown.isRunning == false)
    }

    @Test func zeroSecondsFinishesWithoutWaiting() async {
        let probe = CountdownProbe()
        await probe.countdown.start(seconds: 0) { probe.finished = true }.value

        #expect(probe.ticks.isEmpty)
        #expect(probe.finished)
    }

    @Test func startingAgainDuringCountdownCancelsIt() async {
        let viewModel = RecorderViewModel()
        let probe = CountdownProbe()
        let task = viewModel.countdown.start(seconds: 3) { probe.finished = true }
        #expect(viewModel.countdown.isRunning)

        await viewModel.startRecordingWithCountdown()
        await task.value

        #expect(probe.finished == false)
        #expect(viewModel.countdown.isRunning == false)
    }

    @Test func noCountdownWithoutContentSelected() async {
        let viewModel = RecorderViewModel()
        await viewModel.startRecordingWithCountdown()
        #expect(viewModel.countdown.isRunning == false)
    }
}

/// Stands in for the clock: records the number shown at each tick and returns at once.
@MainActor
private final class CountdownProbe {
    var ticks: [Int?] = []
    var finished = false
    private(set) var countdown = RecordingCountdown()

    /// - Parameter cancelOnTick: Cancels during this tick (1-based), as Esc would.
    init(cancelOnTick: Int? = nil) {
        countdown = RecordingCountdown { [unowned self] in
            self.ticks.append(self.countdown.remaining)
            if self.ticks.count == cancelOnTick {
                self.countdown.cancel()
            }
        }
    }
}
