//
//  TimeMapTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Testing
@testable import Reco

struct TimeMapTests {

    /// A 10 s recording at 4 fps, so every frame boundary is exact in binary.
    private func map(cuts: [Range<Double>], duration: Double = 10) -> TimeMap {
        TimeMap(cuts: cuts, sourceDuration: duration, frameRate: 4)
    }

    @Test func isTheIdentityWithoutCuts() {
        let map = map(cuts: [])

        #expect(map.outputDuration == 10)
        for time in [0, 2.5, 9.75] {
            #expect(map.outputTime(atSource: time) == time)
            #expect(map.sourceTime(atOutput: time) == time)
        }
    }

    @Test func aCutRemovesItsRangeAndShiftsLaterTimes() {
        let map = map(cuts: [2..<5])

        #expect(map.outputDuration == 7)
        #expect(map.outputTime(atSource: 1) == 1)
        #expect(map.outputTime(atSource: 6) == 3)
        #expect(map.sourceTime(atOutput: 3) == 6)
    }

    @Test func normalizesCutsOutOfOrderOverlappingTouchingOffTheGridAndPastEitherEnd() {
        let map = map(cuts: [8..<12, 2..<3, 2.5..<4, 4..<4.5, -1..<0.6, 6.1..<6.1])

        #expect(map.cuts == [0..<0.5, 2..<4.5, 8..<10])
        #expect(map.keptRanges == [0.5..<2, 4.5..<8])
        #expect(map.outputDuration == 5)
    }

    @Test func roundTripsBetweenOutputAndSource() {
        let map = map(cuts: [2..<4, 6..<7])

        #expect(map.outputDuration == 7)
        for output in [0, 1.75, 2, 3.5, 6.75] {
            #expect(map.outputTime(atSource: map.sourceTime(atOutput: output)) == output)
        }
        for source in [0, 1.75, 4, 5.5, 7, 9.75] {
            #expect(map.sourceTime(atOutput: map.outputTime(atSource: source)) == source)
        }
    }

    @Test func showsTheLaterKeptRangeAtTheBoundaryBetweenTwo() {
        let map = map(cuts: [2..<4])

        #expect(map.sourceTime(atOutput: 1.75) == 1.75)
        #expect(map.sourceTime(atOutput: 2) == 4)
    }

    @Test func mapsTimesInACutToTheContentAfterIt() {
        #expect(map(cuts: [2..<4]).outputTime(atSource: 3) == 2)
        #expect(map(cuts: [8..<10]).outputTime(atSource: 9) == 8)
    }

    @Test func sourceTimeClampsToTheOutput() {
        let map = map(cuts: [8..<10])

        #expect(map.sourceTime(atOutput: -1) == 0)
        #expect(map.sourceTime(atOutput: 20) == 8)
    }

    @Test func cuttingEverythingLeavesAnEmptyOutput() {
        let map = map(cuts: [0..<4, 4..<10])

        #expect(map.keptRanges.isEmpty)
        #expect(map.outputDuration == 0)
        #expect(map.sourceTime(atOutput: 1) == 0)
        #expect(map.outputTime(atSource: 5) == 0)
    }

    @Test func theLastBoundaryIsTheRecordingsEndOffTheFrameGrid() {
        let map = map(cuts: [9..<10], duration: 10.1)

        #expect(map.cuts == [9..<10.1])
        #expect(map.keptRanges == [0..<9])
        #expect(map.snapped(10) == 10.1)
    }

    @Test func snapsToTheNearestFrameInsideTheRecording() {
        let map = map(cuts: [])

        #expect(map.snapped(1.1) == 1)
        #expect(map.snapped(1.2) == 1.25)
        #expect(map.snapped(-3) == 0)
        #expect(map.snapped(99) == 10)
    }

    @Test func addsAndRestoresRanges() {
        let map = map(cuts: [2..<4])

        #expect(map.cuts(adding: 3..<5) == [2..<5])
        #expect(map.cuts(adding: 7..<8) == [2..<4, 7..<8])
        #expect(map.cuts(removing: 2.5..<3) == [2..<2.5, 3..<4])
        #expect(map.cuts(removing: 0..<10).isEmpty)
    }

    @Test func movingAKeptRangesEdgeCutsOrRestores() {
        // Kept: 1..<4 and 6..<10
        let map = map(cuts: [0..<1, 4..<6])

        #expect(map.cuts(movingStartOf: 0, to: 2) == [0..<2, 4..<6])
        #expect(map.cuts(movingStartOf: 0, to: 0.5) == [0..<0.5, 4..<6])
        #expect(map.cuts(movingEndOf: 0, to: 5) == [0..<1, 5..<6])
        #expect(map.cuts(movingEndOf: 1, to: 8) == [0..<1, 4..<6, 8..<10])
    }

    @Test func restoringStopsAtTheNeighbouringKeptRange() {
        let map = map(cuts: [0..<1, 4..<6])

        #expect(map.cuts(movingStartOf: 1, to: 0) == [0..<1])
        #expect(map.cuts(movingEndOf: 0, to: 10) == [0..<1])
    }

    @Test func movingAnEdgeKeepsAtLeastOneFrame() {
        let map = map(cuts: [0..<1, 4..<6])

        #expect(map.cuts(movingStartOf: 0, to: 9) == [0..<3.75, 4..<6])
        #expect(map.cuts(movingEndOf: 1, to: 0) == [0..<1, 4..<6, 6.25..<10])
    }

    @Test func aFasterPartLastsItsLengthOverItsRate() {
        let map = TimeMap(cuts: [], speeds: [SpeedRange(range: 2..<6, rate: 4)], sourceDuration: 10, frameRate: 4)

        #expect(map.pieces == [SpeedRange(range: 0..<2, rate: 1), SpeedRange(range: 2..<6, rate: 4), SpeedRange(range: 6..<10, rate: 1)])
        #expect(map.outputDuration == 7)
        #expect(map.outputTime(atSource: 4) == 2.5)
        #expect(map.outputTime(atSource: 8) == 5)
        #expect(map.sourceTime(atOutput: 2.5) == 4)
        #expect(map.sourceTime(atOutput: 3) == 6)
    }

    @Test func cutsAndSpeedsTogether() {
        // Kept: 0..<3 and 5..<10; 2..<6 at 2×, so 2..<3 and 5..<6 play at 2×
        let map = TimeMap(cuts: [3..<5], speeds: [SpeedRange(range: 2..<6, rate: 2)], sourceDuration: 10, frameRate: 4)

        #expect(map.pieces.map(\.range) == [0..<2, 2..<3, 5..<6, 6..<10])
        #expect(map.pieces.map(\.rate) == [1, 2, 2, 1])
        #expect(map.outputDuration == 7)
        // A cut part keeps its speed
        #expect(map.speeds == [SpeedRange(range: 2..<6, rate: 2)])
        #expect(map.outputTime(atSource: 5.5) == 2.75)
        for output in [0, 1.75, 2.25, 2.5, 2.75, 3, 6.5] {
            #expect(map.outputTime(atSource: map.sourceTime(atOutput: output)) == output)
        }
        for source in [0, 2.5, 5, 5.5, 6, 9.75] {
            #expect(map.sourceTime(atOutput: map.outputTime(atSource: source)) == source)
        }
    }

    @Test func normalizesSpeedsSnappedSortedApartAndNoneAt1x() {
        let map = TimeMap(
            cuts: [],
            speeds: [SpeedRange(range: 6.1..<8, rate: 3), SpeedRange(range: 1..<4, rate: 2), SpeedRange(range: 3..<5, rate: 4), SpeedRange(range: 8..<9, rate: 1)],
            sourceDuration: 10, frameRate: 4
        )

        // Where two overlap, the earlier wins
        #expect(map.speeds == [SpeedRange(range: 1..<4, rate: 2), SpeedRange(range: 4..<5, rate: 4), SpeedRange(range: 6..<8, rate: 3)])
    }

    @Test func settingASpeedReplacesWhatTheRangeHad() {
        let map = TimeMap(cuts: [], speeds: [SpeedRange(range: 2..<6, rate: 4)], sourceDuration: 10, frameRate: 4)

        #expect(map.speeds(setting: 2, for: 4..<8) == [SpeedRange(range: 2..<4, rate: 4), SpeedRange(range: 4..<8, rate: 2)])
        #expect(map.speeds(setting: 1, for: 3..<4) == [SpeedRange(range: 2..<3, rate: 4), SpeedRange(range: 4..<6, rate: 4)])
        #expect(map.speeds(setting: 1, for: 0..<10).isEmpty)
        #expect(map.speeds(adding: [SpeedRange(range: 7..<9, rate: 3)]) == [SpeedRange(range: 2..<6, rate: 4), SpeedRange(range: 7..<9, rate: 3)])
    }

    @Test func tellsTheRateAndWhetherATimeIsKept() {
        let map = TimeMap(cuts: [3..<5], speeds: [SpeedRange(range: 2..<6, rate: 2)], sourceDuration: 10, frameRate: 4)

        #expect(map.rate(atSource: 1) == 1)
        #expect(map.rate(atSource: 4) == 2)
        #expect(map.rate(atSource: 6) == 1)
        #expect(map.outputTime(ifKept: 4) == nil)
        #expect(map.outputTime(ifKept: 5.5) == 2.75)
    }

    @Test func segmentsDivideKeptRangesAtSplitsInsideThem() {
        let map = map(cuts: [4..<6])

        // A duplicate, one in the cut, one on a kept range's edge, and one off the frame grid
        #expect(map.segments(splitAt: [2, 2, 5, 6, 8.1, 0]) == [0..<2, 2..<4, 6..<8, 8..<10])
        #expect(map.segments(splitAt: []) == map.keptRanges)
    }
}
