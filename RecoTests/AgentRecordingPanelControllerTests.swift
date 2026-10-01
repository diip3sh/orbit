//
//  AgentRecordingPanelControllerTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct AgentRecordingPanelControllerTests {

    private let screen = CGRect(x: 100, y: 50, width: 1000, height: 800)

    @Test func theTopEdgeIsAShareOfTheWayDownAndItIsCentred() {
        let frame = AgentRecordingPanelController.frame(height: 200, in: screen)

        #expect(frame.width == 600)
        #expect(frame.midX == screen.midX)
        #expect(frame.maxY == screen.maxY - 0.22 * screen.height)
    }

    @Test func growingKeepsTheTopEdgeStill() {
        let small = AgentRecordingPanelController.frame(height: 160, in: screen)
        let tall = AgentRecordingPanelController.frame(height: 300, in: screen)

        #expect(small.maxY == tall.maxY)
        #expect(tall.height == 300)
    }

    @Test func itNeverGoesBelowTheScreenOrBeyondItsSides() {
        let tall = AgentRecordingPanelController.frame(height: 5_000, in: screen)
        let narrow = AgentRecordingPanelController.frame(height: 100, in: CGRect(x: 0, y: 0, width: 400, height: 800))

        #expect(tall.minY == screen.minY)
        #expect(narrow.minX == 0)
    }
}
