//
//  PinControllerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 29.09.26.
//

import CoreGraphics
import Testing
@testable import Reco

struct PinControllerTests {

    private let screen = CGRect(x: 0, y: 70, width: 1512, height: 875)

    @Test func smallShotsPinAtTheirOnScreenSizeWhereTheCardWas() {
        let frame = PinController.frame(for: CGSize(width: 400, height: 300), at: CGPoint(x: 16, y: 86), in: screen)

        #expect(frame == CGRect(x: 16, y: 86, width: 400, height: 300))
    }

    @Test func largeShotsShrinkToFitTheScreen() {
        let frame = PinController.frame(for: CGSize(width: 3024, height: 1750), at: CGPoint(x: 16, y: 86), in: screen)

        #expect(frame == CGRect(x: 0, y: 70, width: 1512, height: 875))
    }

    @Test func wideShotsKeepTheirAspectRatio() {
        let frame = PinController.frame(for: CGSize(width: 3024, height: 500), at: CGPoint(x: 16, y: 86), in: screen)

        #expect(frame.size == CGSize(width: 1512, height: 250))
    }

    @Test func pinsMoveBackOnScreen() {
        let frame = PinController.frame(for: CGSize(width: 400, height: 300), at: CGPoint(x: 1400, y: 800), in: screen)

        #expect(frame.origin == CGPoint(x: 1112, y: 645))
    }
}
