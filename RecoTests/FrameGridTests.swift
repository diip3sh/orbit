//
//  FrameGridTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import Testing
@testable import Reco

struct FrameGridTests {

    private let grid = FrameGrid(frameRate: 60, duration: 10)

    @Test func countsTheFramesInTheVideo() {
        #expect(grid.frameCount == 600)
        #expect(grid.lastFrame == 599)
    }

    @Test func aTimeShowsTheLastFrameStartingAtOrBeforeIt() {
        #expect(grid.frame(at: 0.5) == 30)
        #expect(grid.frame(at: 0.5 + 0.9 / 60) == 30)
    }

    @Test func everyFrameStartMapsBackToItsFrame() {
        for frame in 0...grid.lastFrame {
            #expect(grid.frame(at: grid.time(ofFrame: frame)) == frame)
        }
    }

    @Test func timesOutsideTheVideoClampToItsEnds() {
        #expect(grid.frame(at: -1) == 0)
        #expect(grid.frame(at: 10) == 599)
        #expect(grid.frame(at: 60) == 599)
    }
}
