//
//  NotchGeometryTests.swift
//  RecoTests
//

import CoreGraphics
import Testing
@testable import Reco

struct NotchGeometryTests {

    /// A 14-inch MacBook Pro: 1512×982 pt, a 32 pt tall notch of 184 pt in the middle
    private let notched = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        leftArea: CGRect(x: 0, y: 950, width: 664, height: 32),
        rightArea: CGRect(x: 848, y: 950, width: 664, height: 32)
    )

    @Test func theNotchIsTheGapBetweenTheMenuBarsTwoHalves() {
        #expect(notched.hasNotch)
        #expect(notched.collapsed == CGRect(x: 664, y: 950, width: 184, height: 32))
    }

    @Test func thePanelOpensFromTheNotchAndHangsBelowItsHeight() {
        // 32 pt of notch, then the body
        #expect(notched.expanded == CGRect(x: 476, y: 982 - 164, width: 560, height: 164))
        #expect(notched.expanded.midX == notched.collapsed.midX)
        #expect(notched.expanded.maxY == notched.collapsed.maxY)
        #expect(notched.contentTopInset == 32)
    }

    @Test func peekingGrowsTheNotchSevenAndAHalfPointsToEachSideAndFiveDown() {
        #expect(notched.peek == CGRect(x: 656.5, y: 945, width: 199, height: 37))
        #expect(notched.peek.maxY == notched.collapsed.maxY)
        #expect(notched.peek.midX == notched.collapsed.midX)
    }

    @Test func theOneWindowHoldsEveryShapeWithRoomForTheSpringsOvershootAndTheShadow() {
        let window = notched.window

        #expect(window == CGRect(x: 452, y: 794, width: 608, height: 188))
        #expect(window.maxY == notched.collapsed.maxY)
        #expect(window.midX == notched.collapsed.midX)
        #expect(window.contains(notched.collapsed))
        #expect(window.contains(notched.peek))
        #expect(window.contains(notched.expanded))
        // The open spring overshoots ~2% (11 pt on 560) and the shadow blurs 6 pt past that
        let overshoot: CGFloat = NotchGeometry.expandedWidth * 0.02
        #expect(NotchGeometry.windowRoom > overshoot / 2 + NotchMotion.shadowRadius)
    }

    @Test func thePillsWindowIsFlushWithTheTopToo() {
        let screen = CGRect(x: 1512, y: 200, width: 2560, height: 1440)
        let window = NotchGeometry(screenFrame: screen, leftArea: nil, rightArea: nil).window

        #expect(window.maxY == screen.maxY)
        #expect(window.midX == screen.midX)
        #expect(window.width == 560 + NotchGeometry.windowRoom * 2)
    }

    @Test(arguments: [(nil as CGRect?, nil as CGRect?), (CGRect.zero, CGRect.zero)])
    func aScreenWithoutAreasGetsAPillAtTheTopCentre(left: CGRect?, right: CGRect?) {
        let geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), leftArea: left, rightArea: right)

        #expect(!geometry.hasNotch)
        #expect(geometry.collapsed == CGRect(x: 900, y: 1072, width: 120, height: 8))
        #expect(geometry.peek == CGRect(x: 892.5, y: 1067, width: 135, height: 13))
        #expect(geometry.contentTopInset == 12)
        #expect(geometry.expanded == CGRect(x: 680, y: 1080 - 144, width: 560, height: 144))
    }

    @Test func aSecondaryScreenKeepsItsOrigin() {
        // To the right of and above the main one, so its origin is neither 0 nor positive in y alone
        let frame = CGRect(x: 1512, y: 200, width: 2560, height: 1440)
        let geometry = NotchGeometry(screenFrame: frame, leftArea: nil, rightArea: nil)

        #expect(geometry.collapsed == CGRect(x: 1512 + 1280 - 60, y: 1640 - 8, width: 120, height: 8))
        #expect(geometry.expanded.midX == frame.midX)
        #expect(geometry.expanded.maxY == frame.maxY)
        #expect(frame.contains(geometry.expanded))
        #expect(frame.contains(geometry.peek))
    }

    @Test func aNotchOnASecondaryScreenIsFoundFromTheWidthsAlone() {
        let frame = CGRect(x: -1728, y: -100, width: 1728, height: 1117)
        let geometry = NotchGeometry(
            screenFrame: frame,
            leftArea: CGRect(x: -1728, y: 985, width: 770, height: 32),
            rightArea: CGRect(x: -770, y: 985, width: 770, height: 32)
        )

        #expect(geometry.collapsed == CGRect(x: -958, y: 985, width: 188, height: 32))
    }

    @Test func thePanelStaysOnTheScreen() {
        // A narrow screen: the panel is as wide as it
        let narrow = CGRect(x: 100, y: 0, width: 400, height: 300)
        let fitted = NotchGeometry(screenFrame: narrow, leftArea: nil, rightArea: nil)
        #expect(fitted.expanded.minX == narrow.minX)
        #expect(fitted.expanded.width == 400)

        // A notch far from the middle: the panel is pushed back against the edge
        let lopsided = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 800),
            leftArea: CGRect(x: 0, y: 768, width: 100, height: 32),
            rightArea: CGRect(x: 200, y: 768, width: 1000, height: 32)
        )
        #expect(lopsided.collapsed.midX == 150)
        #expect(lopsided.expanded.minX == 0)
        #expect(lopsided.expanded.width == 560)

        // A screen shorter than the panel
        let short = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 800, height: 100), leftArea: nil, rightArea: nil)
        #expect(short.expanded.height == 100)
        #expect(short.expanded.minY == 0)
    }

    @Test func areasThatLeaveNoRoomForANotchFallBackToThePill() {
        let geometry = NotchGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1000, height: 800),
            leftArea: CGRect(x: 0, y: 768, width: 600, height: 32),
            rightArea: CGRect(x: 400, y: 768, width: 600, height: 32)
        )
        #expect(!geometry.hasNotch)
    }
}
