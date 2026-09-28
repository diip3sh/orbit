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
    /// The cursor, when given, rests on the click.
    private func plan(at time: Double, zooms: [ZoomSegment] = [], cursor: InputTelemetry.CursorSprite? = nil) -> RenderPlan {
        RenderPlan(
            timeMap: TimeMap(cuts: [], sourceDuration: 10, frameRate: 60),
            videoSize: bounds.size,
            camera: CameraPath(zooms: zooms, cursor: [], duration: 10),
            cursor: cursor.flatMap { _ in CursorPath(telemetry: cursorTelemetry, style: CursorStyle(), duration: 10, videoHeight: bounds.height) },
            cursorShapes: cursor.map { CursorShapeTrack(telemetry: cursorTelemetry, duration: 10, arrow: $0) } ?? .none,
            clicks: [ClickMarker(time: time, position: CGPoint(x: 100, y: 200), diameter: 100)],
            clickDuration: 0.5,
            clickRing: OverlayImages.ring(diameter: 100, color: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)),
            keystrokes: [KeystrokeChip(time: time, image: 0)],
            chipImages: [OverlayImages.chip(label: "⌘C", height: 30)]
        )
    }

    /// A 200×150 pt display recorded at 2 px per point, with the cursor at (50, 50) pt: (100, 200)
    /// in Core Image pixels.
    private var cursorTelemetry: InputTelemetry {
        let screen = CGRect(x: 0, y: 0, width: 200, height: 150)
        var telemetry = InputTelemetry(capture: .init(kind: .display, videoSize: bounds.size, cursorInVideo: false), keystrokesAvailable: false)
        telemetry.geometry = [.init(time: 0, screenRect: screen, contentRect: screen, contentScale: 1, scaleFactor: 2)]
        telemetry.cursor = [.init(time: 0, location: CGPoint(x: 50, y: 50))]
        return telemetry
    }

    /// Zoomed 2× on the click point, (100, 200) from the bottom-left or (0.25, 1/3) from the top-left.
    private let zoomOnClick = ZoomSegment(range: 0..<10, scale: 2, focus: .fixed(center: CGPoint(x: 0.25, y: 1.0 / 3)))

    /// Green, 8×8 px for 4×4 pt, with its hot spot at its top-left corner.
    private let greenSquare = InputTelemetry.CursorSprite.drawn(pixels: CGSize(width: 8, height: 8), size: CGSize(width: 4, height: 4)) {
        $0.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
        $0.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
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
        // The view has settled by 3 s, so the ring is drawn twice as big, around the frame's centre
        let plan = plan(at: 3, zooms: [zoomOnClick])
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

    @Test func drawsTheCursorWithItsHotspotOnTheClickAtEveryZoom() {
        let frame = CIImage(color: .black).cropped(to: bounds)

        // 4 pt at 2 px per point, below and right of the click point
        let unzoomed = FrameRenderer.render(frame, at: 3, plan: plan(at: 3, cursor: greenSquare))
        #expect(unzoomed.pixel(at: CGPoint(x: 100, y: 199)) == [0, 255, 0, 255])
        #expect(unzoomed.pixel(at: CGPoint(x: 107, y: 192)) == [0, 255, 0, 255])
        #expect(unzoomed.pixel(at: CGPoint(x: 99, y: 199))[1] < 128)
        #expect(unzoomed.pixel(at: CGPoint(x: 100, y: 200))[1] < 128)

        // Twice that, from the frame's centre, where the ring is. Magnified, the edge pixels blend
        let zoomed = FrameRenderer.render(frame, at: 3, plan: plan(at: 3, zooms: [zoomOnClick], cursor: greenSquare))
        #expect(zoomed.pixel(at: CGPoint(x: 201, y: 148)) == [0, 255, 0, 255])
        #expect(zoomed.pixel(at: CGPoint(x: 214, y: 135)) == [0, 255, 0, 255])
        #expect(zoomed.pixel(at: CGPoint(x: 199, y: 149))[1] < 128)
        #expect(zoomed.pixel(at: CGPoint(x: 200, y: 150))[1] < 128)
    }

    @Test func drawsTheZoomedCursorFromItsFullResolutionImage() {
        // Alternate black and white columns, 16×16 px for 4×4 pt: 4 px per point
        let stripes = InputTelemetry.CursorSprite.drawn(pixels: CGSize(width: 16, height: 16), size: CGSize(width: 4, height: 4)) { context in
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
            context.setFillColor(gray: 0, alpha: 1)
            for column in stride(from: 0, to: 16, by: 2) {
                context.fill(CGRect(x: column, y: 0, width: 1, height: 16))
            }
        }
        let frame = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: bounds)

        // At 2× on a 2 px per point video, one of the image's pixels is one of the frame's
        let zoomed = FrameRenderer.render(frame, at: 3, plan: plan(at: 3, zooms: [zoomOnClick], cursor: stripes))
        let row = (200..<216).map { zoomed.pixel(at: CGPoint(x: $0, y: 140))[0] }
        #expect(row == Array(repeating: [UInt8]([0, 255]), count: 8).flatMap { $0 })
        // Unzoomed, the columns blend
        let unzoomed = FrameRenderer.render(frame, at: 3, plan: plan(at: 3, cursor: stripes))
        #expect((1..<255).contains(unzoomed.pixel(at: CGPoint(x: 102, y: 196))[0]))
    }
}
