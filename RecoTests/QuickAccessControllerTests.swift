//
//  QuickAccessControllerTests.swift
//  RecoTests
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import SwiftUI
import Testing
@testable import Reco

struct QuickAccessControllerTests {

    private let card = CGSize(width: 230, height: 210)

    @Test func bottomLeftOfAStandardDisplay() {
        let frame = QuickAccessController.panelFrame(in: CGRect(x: 0, y: 70, width: 1512, height: 875), size: card)

        #expect(frame.origin == CGPoint(x: 16, y: 86))
        #expect(frame.size == card)
    }

    @Test func bottomLeftOfANegativeOriginDisplay() {
        let frame = QuickAccessController.panelFrame(in: CGRect(x: -1920, y: 0, width: 1920, height: 1080), size: card)

        #expect(frame.origin == CGPoint(x: -1904, y: 16))
    }

    // MARK: - Beside the pointer after an area capture

    /// 1512×875 above a 70 pt Dock; the card is 230×210 with a 16 pt margin
    private let visibleFrame = CGRect(x: 0, y: 70, width: 1512, height: 875)

    private func origin(pointer: CGPoint, region: CGRect) -> CGPoint {
        QuickAccessController.panelFrame(in: visibleFrame, size: card, pointer: pointer, awayFrom: region).origin
    }

    @Test func belowRightOfThePointerAfterDraggingDownAndRight() {
        let region = CGRect(x: 600, y: 500, width: 300, height: 200)

        #expect(origin(pointer: CGPoint(x: 900, y: 500), region: region) == CGPoint(x: 916, y: 274))
    }

    @Test func aboveLeftOfThePointerAfterDraggingUpAndLeft() {
        let region = CGRect(x: 600, y: 500, width: 300, height: 200)

        #expect(origin(pointer: CGPoint(x: 600, y: 700), region: region) == CGPoint(x: 354, y: 716))
    }

    @Test func slidBackOnScreenWhenThePointerIsInACorner() {
        let region = CGRect(x: 1300, y: 100, width: 200, height: 150)

        #expect(origin(pointer: CGPoint(x: 1500, y: 100), region: region) == CGPoint(x: 1266, y: 86))
    }

    // MARK: - The card's size

    @Test func takesALandscapeShotsShapeWithinTheLargestCard() {
        // 1512×982 fitted into 244×204 (the largest card less its edge): 244×158
        #expect(QuickAccessController.cardSize(for: CGSize(width: 1512, height: 982)) == CGSize(width: 260, height: 174))
    }

    @Test func takesAPortraitShotsShapeWithinTheLargestCard() {
        // 400×1000 fitted into 244×204: 82×204, widened to the smallest card
        #expect(QuickAccessController.cardSize(for: CGSize(width: 400, height: 1000)) == CGSize(width: 200, height: 220))
    }

    @Test func neverEnlargesASmallShotPastTheSmallestCard() {
        #expect(QuickAccessController.cardSize(for: CGSize(width: 40, height: 30)) == QuickAccessController.minCardSize)
        #expect(QuickAccessController.cardSize(for: CGSize(width: 200, height: 100)) == CGSize(width: 216, height: 120))
        #expect(QuickAccessController.cardSize(for: .zero) == QuickAccessController.maxCardSize)
    }

    // MARK: - Where the card grows from

    @Test func growsFromTheCornerNearestThePointer() {
        let card = CGRect(x: 916, y: 274, width: 230, height: 210)

        // Pointer left of and below the card: its bottom-left corner. Screen y grows upwards.
        #expect(QuickAccessController.anchor(for: card, pointer: CGPoint(x: 900, y: 260)) == .bottomLeading)
        #expect(QuickAccessController.anchor(for: card, pointer: CGPoint(x: 1200, y: 500)) == .topTrailing)
        #expect(QuickAccessController.anchor(for: card, pointer: nil) == .bottomLeading)
    }
}
