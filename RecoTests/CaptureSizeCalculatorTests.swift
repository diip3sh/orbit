//
//  CaptureSizeCalculatorTests.swift
//  RecoTests
//
//  Created by Joshua Sattler on 29.08.26.
//

import CoreGraphics
import Foundation
import Testing
@testable import Reco

@MainActor
struct CaptureSizeCalculatorTests {

    // MARK: - Fixtures

    /// The 2x built-in display, at the origin of the global CoreGraphics space.
    private let builtIn = DisplayGeometry(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        scaleFactor: 2
    )

    /// A 1x external display arranged *above* the built-in one, so it has a negative Y origin.
    /// This is the arrangement that makes `SCContentFilter.pointPixelScale` report 2.0.
    private let externalAbove = DisplayGeometry(
        frame: CGRect(x: 2099, y: -1440, width: 2560, height: 1440),
        scaleFactor: 1
    )

    /// The same 1x external display arranged to the right of the built-in one.
    private let externalBeside = DisplayGeometry(
        frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
        scaleFactor: 1
    )

    // MARK: - windowScale

    @Test func windowScaleUsesDisplayAboveThePrimaryRatherThanTheReportedScale() {
        let window = CGRect(x: 2099, y: -1440, width: 2560, height: 1410)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [builtIn, externalAbove],
            fallback: 2
        )

        #expect(scale == 1)
    }

    @Test func windowScaleUsesDisplayBesideThePrimary() {
        let window = CGRect(x: 1512, y: 0, width: 2560, height: 1410)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [builtIn, externalBeside],
            fallback: 2
        )

        #expect(scale == 1)
    }

    @Test func windowScaleUsesTheBuiltInDisplayForAWindowOnIt() {
        let window = CGRect(x: 0, y: 80, width: 1512, height: 949)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [builtIn, externalAbove],
            fallback: 2
        )

        #expect(scale == 2)
    }

    @Test func windowScaleFallsBackWhenNoDisplayOverlaps() {
        let window = CGRect(x: -5000, y: -5000, width: 400, height: 300)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [builtIn, externalAbove],
            fallback: 2
        )

        #expect(scale == 2)
    }

    @Test func windowScaleFallsBackWhenNoDisplaysAreKnown() {
        let window = CGRect(x: 0, y: 80, width: 1512, height: 949)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [],
            fallback: 1.5
        )

        #expect(scale == 1.5)
    }

    @Test func windowScalePrefersTheDisplayShowingMostOfAStraddlingWindow() {
        // 300pt on the built-in, 700pt on the external beside it.
        let window = CGRect(x: 1212, y: 100, width: 1000, height: 600)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [builtIn, externalBeside],
            fallback: 2
        )

        #expect(scale == 1)
    }

    @Test func windowScaleIgnoresDisplaysTouchingOnlyTheWindowEdge() {
        // The window ends exactly where the external display begins.
        let window = CGRect(x: 0, y: 80, width: 1512, height: 902)

        let scale = CaptureSizeCalculator.windowScale(
            windowFrame: window,
            displays: [builtIn, externalBeside],
            fallback: 1
        )

        #expect(scale == 2)
    }

    // MARK: - videoSize

    @Test func videoSizeAppliesScaleWhenCapturingNatively() {
        let size = CaptureSizeCalculator.videoSize(
            contentRect: CGRect(x: 0, y: 80, width: 1512, height: 949),
            scale: 2,
            useNativeResolution: true
        )

        #expect(size == CGSize(width: 3024, height: 1898))
    }

    @Test func videoSizeMatchesScreenCaptureKitForAOneTimesWindow() {
        // The regression from issue #190: this used to be scaled by the reported 2.0 and produce
        // a 5120x2820 frame holding 2560x1410 of content.
        let size = CaptureSizeCalculator.videoSize(
            contentRect: CGRect(x: 0, y: 0, width: 2560, height: 1410),
            scale: 1,
            useNativeResolution: true
        )

        #expect(size == CGSize(width: 2560, height: 1410))
    }

    @Test func videoSizeIgnoresScaleWhenNotCapturingNatively() {
        let size = CaptureSizeCalculator.videoSize(
            contentRect: CGRect(x: 0, y: 80, width: 1512, height: 949),
            scale: 2,
            useNativeResolution: false
        )

        #expect(size == CGSize(width: 1512, height: 949))
    }

    // MARK: - sourceRect

    @Test func sourceRectOnA2xDisplayAtTheOrigin() {
        let rect = CaptureSizeCalculator.sourceRect(
            for: CGRect(x: 100, y: 200, width: 301, height: 150),
            in: CGRect(x: 0, y: 0, width: 1512, height: 982),
            scale: 2
        )

        #expect(rect == CGRect(x: 100, y: 632, width: 301, height: 150))
    }

    @Test func sourceRectRoundsWidthUpToAnEvenPixelCount() {
        let oneX = CaptureSizeCalculator.sourceRect(
            for: CGRect(x: 0, y: 0, width: 301, height: 100),
            in: CGRect(x: 0, y: 0, width: 1512, height: 982),
            scale: 1
        )
        #expect(oneX.width == 302)

        let twoX = CaptureSizeCalculator.sourceRect(
            for: CGRect(x: 0, y: 0, width: 100.25, height: 100),
            in: CGRect(x: 0, y: 0, width: 1512, height: 982),
            scale: 2
        )
        #expect(twoX.width == 101)
    }

    @Test func sourceRectOnAScreenToTheRightOfThePrimary() {
        let rect = CaptureSizeCalculator.sourceRect(
            for: CGRect(x: 1612, y: 100, width: 400, height: 300),
            in: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
            scale: 1
        )

        #expect(rect == CGRect(x: 100, y: 1040, width: 400, height: 300))
    }

    @Test func sourceRectOnAScreenAboveThePrimary() {
        let rect = CaptureSizeCalculator.sourceRect(
            for: CGRect(x: 10, y: 1000, width: 200, height: 100),
            in: CGRect(x: 0, y: 982, width: 2560, height: 1440),
            scale: 1
        )

        #expect(rect.origin.y == 1322)
    }
}
