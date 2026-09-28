//
//  QuickAccessControllerTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Testing
@testable import BetterCapture

struct QuickAccessControllerTests {

    @Test func bottomLeftOfAStandardDisplay() {
        let frame = QuickAccessController.panelFrame(in: CGRect(x: 0, y: 70, width: 1512, height: 875))

        #expect(frame.origin == CGPoint(x: 16, y: 86))
        #expect(frame.size == QuickAccessController.cardSize)
    }

    @Test func bottomLeftOfANegativeOriginDisplay() {
        let frame = QuickAccessController.panelFrame(in: CGRect(x: -1920, y: 0, width: 1920, height: 1080))

        #expect(frame.origin == CGPoint(x: -1904, y: 16))
    }
}
