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

    private var plan: RenderPlan {
        plan(at: 1)
    }

    /// A click at (100, 200) with a red ring 100 px wide when grown, and a "⌘C" chip, both at `time`.
    private func plan(at time: Double, zooms: [ZoomSegment] = []) -> RenderPlan {
        RenderPlan(
            timeMap: TimeMap(cuts: [], sourceDuration: 10, frameRate: 60),
            videoSize: bounds.size,
            camera: CameraPath(zooms: zooms, cursor: [], duration: 10),
            clicks: [ClickMarker(time: time, position: CGPoint(x: 100, y: 200), diameter: 100)],
            clickDuration: 0.5,
            clickRing: OverlayImages.ring(diameter: 100, color: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)),
            keystrokes: [KeystrokeChip(time: time, image: 0)],
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

    @Test func zoomMagnifiesTheContentAndTheRingButNotTheChip() {
        // Zoomed 2× on the click point, (100, 200) from the bottom-left or (0.25, 1/3) from the top-left.
        // The view has settled by 3 s, so the ring is drawn twice as big, around the frame's centre
        let zoom = ZoomSegment(range: 0..<10, scale: 2, focus: .fixed(center: CGPoint(x: 0.25, y: 1.0 / 3)))
        let plan = plan(at: 3, zooms: [zoom])
        let viewport = plan.camera.viewport(at: 3)
        #expect(abs(viewport.center.x - 0.25) < 1e-9 && abs(viewport.center.y - 1.0 / 3) < 1e-9 && abs(viewport.scale - 2) < 1e-9)
        let frame = CIImage(color: .black).cropped(to: bounds)

        let image = FrameRenderer.render(frame, at: 3, plan: plan)

        #expect(image.extent == bounds)
        // The stroke, 16 to 20 px out at 1×, is 32 to 40 px out
        #expect(image.pixel(at: CGPoint(x: 236, y: 150))[0] > 240)
        #expect(image.pixel(at: CGPoint(x: 200, y: 114))[0] > 240)
        #expect(image.pixel(at: CGPoint(x: 248, y: 150)) == [0, 0, 0, 255])
        // The chip keeps its size and place: its left padding, 24 px up plus half its height
        let white = CIImage(color: .white).cropped(to: bounds)
        let chipWidth = plan.chipImages[0].extent.width
        let chip = CGPoint(x: ((bounds.width - chipWidth) / 2).rounded() + 4, y: 24 + 15)
        let unzoomed = FrameRenderer.render(white, at: 3, plan: self.plan(at: 3)).pixel(at: chip)
        #expect(unzoomed[0] < 200)
        #expect(FrameRenderer.render(white, at: 3, plan: plan).pixel(at: chip) == unzoomed)
    }
}
