//
//  ColorPanelPlacementTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

@MainActor
struct ColorPanelPlacementTests {

    private let screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
    private let panel = CGSize(width: 250, height: 400)

    @Test func itOpensRightOfTheWindowWhenThereIsRoom() {
        let origin = ColorPanelPlacement.origin(of: panel, beside: CGRect(x: 100, y: 100, width: 1200, height: 900), in: screen)
        #expect(origin == CGPoint(x: 1308, y: 1000 - 52 - 400))
    }

    @Test func otherwiseItOpensInsideTheWindowLeftOfTheInspector() {
        let origin = ColorPanelPlacement.origin(of: panel, beside: CGRect(x: 300, y: 100, width: 1650, height: 900), in: screen)
        #expect(origin.x == CGFloat(1950 - 340 - 250 - 8))
    }

    @Test func itStaysOnScreen() {
        let origin = ColorPanelPlacement.origin(of: panel, beside: CGRect(x: 0, y: 0, width: 400, height: 300), in: screen)
        #expect(origin.y == 0)
    }
}
