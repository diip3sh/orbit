//
//  FrameRendererTests.swift
//  BetterCaptureTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreImage
import Testing
@testable import BetterCapture

struct FrameRendererTests {

    private let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)

    /// A click at (100, 200) with a red ring 100 px wide when grown, and a "⌘C" chip, both at 1 s.
    private var plan: RenderPlan {
        RenderPlan(
            timeMap: TimeMap(cuts: [], sourceDuration: 10, frameRate: 60),
            videoSize: bounds.size,
            clicks: [ClickMarker(time: 1, position: CGPoint(x: 100, y: 200), diameter: 100)],
            clickDuration: 0.5,
            clickRing: OverlayImages.ring(diameter: 100, color: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)),
            keystrokes: [KeystrokeChip(time: 1, image: 0)],
            chipImages: [OverlayImages.chip(label: "⌘C", height: 30)]
        )
    }

    @Test func drawsTheRingAroundTheClickPoint() {
        let image = FrameRenderer.render(CIImage(color: .black).cropped(to: bounds), at: 1, plan: plan)

        // At the press the ring is 40% of its size: its stroke runs 16 to 20 px from the centre
        #expect(image.pixel(at: CGPoint(x: 118, y: 200))[0] > 240)
        #expect(image.pixel(at: CGPoint(x: 100, y: 181))[0] > 240)
        // Inside, the faint fill; outside, the untouched frame
        #expect((60...200).contains(image.pixel(at: CGPoint(x: 100, y: 200))[0]))
        #expect(image.pixel(at: CGPoint(x: 125, y: 200)) == [0, 0, 0, 255])
        #expect(image.pixel(at: CGPoint(x: 300, y: 100)) == [0, 0, 0, 255])
    }

    @Test func theRingGrowsAndFades() {
        let image = FrameRenderer.render(CIImage(color: .black).cropped(to: bounds), at: 1.25, plan: plan)

        // Halfway through, it's at 92.5% of its size, stroke 37 to 46 px out, and half transparent
        #expect((60...240).contains(image.pixel(at: CGPoint(x: 141, y: 200))[0]))
        #expect(image.pixel(at: CGPoint(x: 152, y: 200)) == [0, 0, 0, 255])
    }

    @Test func showsTheChipCentredAtTheBottomUntilItsHoldEnds() {
        let frame = CIImage(color: .white).cropped(to: bounds)
        let chipWidth = plan.chipImages[0].extent.width
        // Inside the chip's left padding, 24 px up (80% of its height) plus half its height
        let point = CGPoint(x: ((bounds.width - chipWidth) / 2).rounded() + 4, y: 24 + 15)

        let shown = FrameRenderer.render(frame, at: 1.2, plan: plan).pixel(at: point)
        #expect(shown[0] < 200 && shown[0] == shown[1] && shown[1] == shown[2])
        #expect(FrameRenderer.render(frame, at: 1 + KeystrokeChip.holdDuration, plan: plan).pixel(at: point) == [255, 255, 255, 255])
    }
}
