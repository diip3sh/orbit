//
//  FrameRendererTests.swift
//  RecoTests
//
//  Created by Diip3sh on 26.09.26.
//

import CoreImage
import CoreVideo
import Testing
@testable import Reco

struct FrameRendererTests {

    private let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)

    /// Like the compositor's.
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    /// Draws the frame as the compositor does, into a buffer the canvas's size, with half floats for HDR.
    private func render(_ frame: CIImage, at time: Double, plan: RenderPlan) -> CIImage {
        drawn(frame, at: time, plan: plan).map { CIImage(cvPixelBuffer: $0) } ?? .empty()
    }

    private func drawn(_ frame: CIImage, at time: Double, plan: RenderPlan) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil, Int(plan.canvas.size.width), Int(plan.canvas.size.height),
            plan.dynamicRange == .sdr ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_64RGBAHalf,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer
        )
        guard let buffer, (try? FrameRenderer.draw(frame, at: time, plan: plan, into: buffer, context: Self.context)) != nil else {
            return nil
        }
        return buffer
    }

    /// The buffer's bytes, row padding included.
    private func bytes(of buffer: CVPixelBuffer?) -> [UInt8] {
        guard let buffer else { return [] }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return [] }
        return Array(UnsafeRawBufferPointer(start: base, count: CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer)))
    }

    private var plan: RenderPlan {
        plan(at: 1)
    }

    /// A click at (100, 200) with a red ring 100 px wide when grown, and a "⌘C" chip, both at `time`.
    /// The cursor, when given, rests on the click. The video fills the canvas unless `canvas` says
    /// otherwise. The overlays are drawn in `dynamicRange`, as plans draw them.
    private func plan(
        at time: Double, zooms: [ZoomSegment] = [], cursor: InputTelemetry.CursorSprite? = nil, canvas: CanvasStyle = .plain,
        dynamicRange: DynamicRange = .sdr, cursorStyle: CursorStyle? = nil, clickEffect: ClickHighlightStyle.Effect = .circle,
        shutter: Double = 0, telemetry: InputTelemetry? = nil
    ) -> RenderPlan {
        let drawn = cursorStyle.flatMap {
            RenderPlan.drawnCursor(for: telemetry ?? cursorTelemetry, style: $0, duration: 10, videoHeight: bounds.height, arrow: nil)
        }
        let layout = CanvasLayout(style: canvas, videoSize: bounds.size, shorterSide: nil, background: nil)
        return RenderPlan(
            timeMap: TimeMap(cuts: [], sourceDuration: 10, frameRate: 60),
            videoSize: bounds.size,
            camera: CameraPath(zooms: zooms, cursor: [], duration: 10, baseView: layout.baseView),
            cursor: drawn?.path ?? cursor.flatMap { _ in CursorPath(telemetry: cursorTelemetry, style: CursorStyle(), duration: 10, videoHeight: bounds.height) },
            cursorShapes: drawn?.shapes.encoded(in: dynamicRange)
                ?? cursor.map { CursorShapeTrack(telemetry: cursorTelemetry, duration: 10, arrow: $0).encoded(in: dynamicRange) } ?? .none,
            clicks: [ClickMarker(time: time, position: CGPoint(x: 100, y: 200), diameter: 100)],
            clickDuration: 0.5,
            clickRing: OverlayImages.encoded(
                OverlayImages.ring(diameter: 100, color: CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1), filled: clickEffect == .circle), in: dynamicRange
            ),
            clickEffect: clickEffect,
            keystrokes: [KeystrokeChip(time: time, image: 0)],
            chipImages: [OverlayImages.encoded(OverlayImages.chip(label: "⌘C", height: 30), in: dynamicRange)],
            canvas: layout.encoded(in: dynamicRange),
            dynamicRange: dynamicRange,
            shutter: shutter
        )
    }

    @Test func fillingShowsTheMiddleOfTheFrameInTheCanvassShapeUnstretched() {
        // 400×300 filling a square: 300×300 of the frame's middle, from x = 50, at 1×
        let square = CanvasStyle(aspect: .square, fillsFrame: true, padding: 0, cornerRadius: 0, shadow: 0)
        let red = CIImage(color: CIColor(red: 1, green: 0, blue: 0)).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 300))
        let striped = red.composited(over: CIImage(color: .black).cropped(to: bounds))
        let plan = plan(at: 5, canvas: square)
        #expect(plan.canvas.size == CGSize(width: 300, height: 300))

        let image = render(striped, at: 5, plan: plan)

        #expect(image.extent == CGRect(x: 0, y: 0, width: 300, height: 300))
        // The red ends at the frame's x = 100, the output's 50; a stretch to the square would put it at 75
        #expect(image.pixel(at: CGPoint(x: 48, y: 150)) == [255, 0, 0, 255])
        #expect(image.pixel(at: CGPoint(x: 52, y: 150)) == [0, 0, 0, 255])
        #expect(image.pixel(at: CGPoint(x: 74, y: 150)) == [0, 0, 0, 255])
        // The click's ring at the frame's (100, 200) is at the output's (50, 200), its stroke 16 to 20 px out
        #expect(image.pixel(at: CGPoint(x: 50, y: 181))[0] > 240)
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
        let image = render(CIImage(color: .black).cropped(to: bounds), at: 1, plan: plan)

        // At the press the ring is 40% of its size: its stroke runs 16 to 20 px from the centre
        #expect(image.pixel(at: CGPoint(x: 118, y: 200))[0] > 240)
        #expect(image.pixel(at: CGPoint(x: 100, y: 181))[0] > 240)
        // Inside, the faint fill; outside, the untouched frame
        #expect((60...200).contains(image.pixel(at: CGPoint(x: 100, y: 200))[0]))
        #expect(image.pixel(at: CGPoint(x: 125, y: 200)) == [0, 0, 0, 255])
        #expect(image.pixel(at: CGPoint(x: 300, y: 100)) == [0, 0, 0, 255])
    }

    @Test func aRippleDrawsTwoEmptyRingsThatEndWithTheDuration() {
        let frame = CIImage(color: .black).cropped(to: bounds)

        // Halfway through, the first ring has come 71% of the way: 98 px wide, stroke 39 to 49 px out, 29% opaque. The
        // second, 30% later, 29% of the way: 71 px wide, stroke 28 to 35 px out, 71% opaque
        let image = render(frame, at: 1.25, plan: plan(at: 1, clickEffect: .ripple))
        #expect((60...90).contains(image.pixel(at: CGPoint(x: 144, y: 200))[0]))
        #expect((165...200).contains(image.pixel(at: CGPoint(x: 132, y: 200))[0]))
        // Empty inside the rings and between them, unlike a circle
        #expect(image.pixel(at: CGPoint(x: 120, y: 200))[0] == 0)
        #expect(image.pixel(at: CGPoint(x: 137, y: 200))[0] == 0)
        #expect(image.pixel(at: CGPoint(x: 155, y: 200))[0] == 0)

        #expect(render(frame, at: 1.5, plan: plan(at: 1, clickEffect: .ripple)).pixel(at: CGPoint(x: 132, y: 200))[0] == 0)
    }

    @Test func noEffectDrawsNoRing() {
        let frame = CIImage(color: .black).cropped(to: bounds)

        #expect(render(frame, at: 1, plan: plan(at: 1, clickEffect: .off)).pixel(at: CGPoint(x: 118, y: 200)) == [0, 0, 0, 255])
    }

    @Test func theDotCursorIsCentredOnThePoint() {
        let frame = CIImage(color: .black).cropped(to: bounds)

        // 16 pt at 2 px per point: 32 px wide, a 3 px white edge, and a grey (white at 45%, 90% opaque, so about half) inside
        let image = render(frame, at: 5, plan: plan(at: 1, cursorStyle: CursorStyle(appearance: .dot)))
        for offset in [CGPoint(x: 14, y: 0), CGPoint(x: -15, y: 0), CGPoint(x: 0, y: 14), CGPoint(x: 0, y: -15)] {
            #expect(image.pixel(at: CGPoint(x: 100 + offset.x, y: 200 + offset.y))[0] > 240)
        }
        #expect((100...140).contains(image.pixel(at: CGPoint(x: 100, y: 200))[0]))
        #expect(image.pixel(at: CGPoint(x: 100 + 18, y: 200)) == [0, 0, 0, 255])
    }

    @Test func theWhiteArrowsTipIsOnThePoint() {
        let frame = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5)).cropped(to: bounds)

        // The arrow's left edge runs down from the tip at 2 px per point: a black outline 2.5 px wide on it, white inside
        let image = render(frame, at: 5, plan: plan(at: 1, cursorStyle: CursorStyle(appearance: .white)))
        #expect(image.pixel(at: CGPoint(x: 99, y: 190))[0] < 60)
        #expect(image.pixel(at: CGPoint(x: 103, y: 190)) == [255, 255, 255, 255])
        // Nothing left of it or above its tip but the faint shadow
        #expect(abs(Int(image.pixel(at: CGPoint(x: 85, y: 190))[0]) - 128) < 6)
        #expect(abs(Int(image.pixel(at: CGPoint(x: 100, y: 215))[0]) - 128) < 6)
    }

    @Test func theRingGrowsAndFades() {
        let image = render(CIImage(color: .black).cropped(to: bounds), at: 1.25, plan: plan)

        // Halfway through, it's at 92.5% of its size, stroke 37 to 46 px out, and half transparent
        #expect((60...240).contains(image.pixel(at: CGPoint(x: 141, y: 200))[0]))
        #expect(image.pixel(at: CGPoint(x: 152, y: 200)) == [0, 0, 0, 255])
    }

    @Test func showsTheChipCentredAtTheBottomUntilItsHoldEnds() {
        let frame = CIImage(color: .white).cropped(to: bounds)
        let chipWidth = plan.chipImages[0].extent.width
        // Inside the chip's left padding, 24 px up (80% of its height) plus half its height
        let point = CGPoint(x: ((bounds.width - chipWidth) / 2).rounded() + 4, y: 24 + 15)

        let shown = render(frame, at: 1.2, plan: plan).pixel(at: point)
        #expect(shown[0] < 200 && shown[0] == shown[1] && shown[1] == shown[2])
        #expect(render(frame, at: 1 + KeystrokeChip.holdDuration, plan: plan).pixel(at: point) == [255, 255, 255, 255])
    }

    @Test func zoomMagnifiesTheContentAndTheRingButNotTheChip() {
        // The view has settled by 3 s, so the ring is drawn twice as big, around the frame's centre
        let plan = plan(at: 3, zooms: [zoomOnClick])
        let viewport = plan.camera.viewport(at: 3)
        #expect(abs(viewport.center.x - 0.25) < 1e-9 && abs(viewport.center.y - 1.0 / 3) < 1e-9 && abs(viewport.scale - 2) < 1e-9)
        let frame = CIImage(color: .black).cropped(to: bounds)

        let image = render(frame, at: 3, plan: plan)

        #expect(image.extent == bounds)
        // The stroke, 16 to 20 px out at 1×, is 32 to 40 px out
        #expect(image.pixel(at: CGPoint(x: 236, y: 150))[0] > 240)
        #expect(image.pixel(at: CGPoint(x: 200, y: 114))[0] > 240)
        #expect(image.pixel(at: CGPoint(x: 248, y: 150)) == [0, 0, 0, 255])
        // The chip keeps its size and place: its left padding, 24 px up plus half its height
        let white = CIImage(color: .white).cropped(to: bounds)
        let chipWidth = plan.chipImages[0].extent.width
        let chip = CGPoint(x: ((bounds.width - chipWidth) / 2).rounded() + 4, y: 24 + 15)
        let unzoomed = render(white, at: 3, plan: self.plan(at: 3)).pixel(at: chip)
        #expect(unzoomed[0] < 200)
        #expect(render(white, at: 3, plan: plan).pixel(at: chip) == unzoomed)
    }

    @Test func drawsTheCursorWithItsHotspotOnTheClickAtEveryZoom() {
        let frame = CIImage(color: .black).cropped(to: bounds)

        // 4 pt at 2 px per point, below and right of the click point
        let unzoomed = render(frame, at: 3, plan: plan(at: 3, cursor: greenSquare))
        #expect(unzoomed.pixel(at: CGPoint(x: 100, y: 199)) == [0, 255, 0, 255])
        #expect(unzoomed.pixel(at: CGPoint(x: 107, y: 192)) == [0, 255, 0, 255])
        #expect(unzoomed.pixel(at: CGPoint(x: 99, y: 199))[1] < 128)
        #expect(unzoomed.pixel(at: CGPoint(x: 100, y: 200))[1] < 128)

        // Twice that, from the frame's centre, where the ring is. Magnified, the edge pixels blend
        let zoomed = render(frame, at: 3, plan: plan(at: 3, zooms: [zoomOnClick], cursor: greenSquare))
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
        let zoomed = render(frame, at: 3, plan: plan(at: 3, zooms: [zoomOnClick], cursor: stripes))
        let row = (200..<216).map { zoomed.pixel(at: CGPoint(x: $0, y: 140))[0] }
        #expect(row == Array(repeating: [UInt8]([0, 255]), count: 8).flatMap { $0 })
        // Unzoomed, the columns blend
        let unzoomed = render(frame, at: 3, plan: plan(at: 3, cursor: stripes))
        #expect((1..<255).contains(unzoomed.pixel(at: CGPoint(x: 102, y: 196))[0]))
    }

    /// A white background, the video in the middle with 10% padding and corners 15 px round: 320×240 px
    /// at (40, 30), four fifths of its size.
    private let whiteFrame = CanvasStyle(aspect: .standard, padding: 0.1, cornerRadius: 0.05, shadow: 0, background: .color, color: RGBAColor(red: 1, green: 1, blue: 1, alpha: 1))

    @Test func drawsTheVideoWithRoundedCornersOnTheBackground() {
        let plan = plan(at: 0, canvas: whiteFrame)
        let image = render(CIImage(color: .black).cropped(to: bounds), at: 5, plan: plan)

        #expect(plan.canvas.videoFrame == CGRect(x: 40, y: 30, width: 320, height: 240))
        #expect(image.pixel(at: CGPoint(x: 10, y: 10)) == [255, 255, 255, 255])
        #expect(image.pixel(at: CGPoint(x: 200, y: 150)) == [0, 0, 0, 255])
        // The corner is rounded off; its edges aren't
        #expect(image.pixel(at: CGPoint(x: 40, y: 30)) == [255, 255, 255, 255])
        #expect(image.pixel(at: CGPoint(x: 40, y: 50)) == [0, 0, 0, 255])
        #expect(image.pixel(at: CGPoint(x: 60, y: 30)) == [0, 0, 0, 255])
    }

    @Test func movesTheClickCursorAndChipWithTheVideo() {
        let frame = CIImage(color: .black).cropped(to: bounds)

        // The click at (100, 200) is at (120, 190), its stroke 12.8 to 16 px out at the press
        let image = render(frame, at: 1, plan: plan(at: 1, cursor: greenSquare, canvas: whiteFrame))
        #expect(image.pixel(at: CGPoint(x: 134, y: 190))[0] > 200)
        // The cursor's image, 6.4 px wide, hangs from the click point
        #expect(image.pixel(at: CGPoint(x: 122, y: 186)) == [0, 255, 0, 255])

        // Zoomed 2× on the click, the ring is around the video's centre, its stroke 25.6 to 32 px out
        let zoomed = render(frame, at: 3, plan: plan(at: 3, zooms: [zoomOnClick], canvas: whiteFrame))
        #expect(zoomed.pixel(at: CGPoint(x: 229, y: 150))[0] > 200)

        // The chip sits 80% of its height above the video's bottom edge
        let white = CIImage(color: .white).cropped(to: bounds)
        let chipWidth = plan.chipImages[0].extent.width
        let chip = render(white, at: 1.2, plan: plan(at: 1, canvas: whiteFrame))
            .pixel(at: CGPoint(x: (200 - chipWidth / 2).rounded() + 4, y: 30 + 24 + 15))
        #expect(chip[0] < 200 && chip[0] == chip[2])
    }

    @Test func drawsHDRFramesAsTheyAreOnABackgroundAtSDRWhite() {
        let frame = CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3)).cropped(to: bounds)
        let image = render(frame, at: 5, plan: plan(at: 0, canvas: whiteFrame, dynamicRange: .pq))

        // Without color management, the frame's PQ values stay as they are
        let video = image.values(at: CGPoint(x: 200, y: 150))
        #expect(abs(video[0] - 0.3) < 0.001 && video[3] == 1)
        // The white background at 203 nits, BT.2408's reference white
        #expect(abs(image.values(at: CGPoint(x: 10, y: 10))[0] - 0.58) < 0.001)
    }

    @Test func aTransparentBackgroundStaysClearBesideTheShadow() {
        let canvas = CanvasStyle(padding: 0.1, cornerRadius: 0, shadow: 1, background: .transparent)
        let image = render(CIImage(color: .black).cropped(to: bounds), at: 5, plan: plan(at: 0, canvas: canvas))

        #expect(image.pixel(at: CGPoint(x: 2, y: 298)) == [0, 0, 0, 0])
        // The shadow, below the video
        #expect(image.pixel(at: CGPoint(x: 200, y: 26))[3] > 40)
        #expect(image.pixel(at: CGPoint(x: 200, y: 150)) == [0, 0, 0, 255])
    }

    // MARK: - Motion blur

    /// Left half black, right half white, with a vertical edge at x = 150.
    private var edge: CIImage {
        CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: 150, height: 300)).composited(over: CIImage(color: .white).cropped(to: bounds))
    }

    /// Squares of two greys, so a frame drawn from other pixels, or blended, differs in many bytes.
    private var checkers: CIImage {
        CIFilter(name: "CICheckerboardGenerator", parameters: [
            "inputWidth": 7, "inputColor0": CIColor(red: 0.2, green: 0.4, blue: 0.9), "inputColor1": CIColor(red: 0.9, green: 0.8, blue: 0.1), "inputCenter": CIVector(x: 3, y: 5)
        ])?.outputImage?.cropped(to: bounds) ?? .empty()
    }

    /// One 60 fps frame's worth of shutter.
    private let frame = 1.0 / 60

    @Test func aStillCameraDrawsExactlyWhatWithoutBlurDoes() {
        // No zooms, and a zoom that has long settled (the spring is within 0.04 px of it by 1.4 s)
        for zooms in [[], [zoomOnClick]] {
            let sharp = bytes(of: drawn(checkers, at: 5, plan: plan(at: 5, zooms: zooms)))
            let blurred = bytes(of: drawn(checkers, at: 5, plan: plan(at: 5, zooms: zooms, shutter: frame)))
            #expect(!sharp.isEmpty && sharp == blurred)
            #expect(FrameRenderer.placements(at: 5, plan: plan(at: 5, zooms: zooms, shutter: frame)).count == 1)
        }
    }

    @Test func aMovingCameraSpreadsAnEdgeAcrossMorePixels() {
        // 0.1 s into a 2× zoom the view is magnifying by about 4 per second
        func width(of image: CIImage) -> Int {
            (0..<Int(bounds.width)).filter { (10...245).contains(image.pixel(at: CGPoint(x: $0, y: 150))[0]) }.count
        }
        let sharp = width(of: render(edge, at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick])))
        let blurred = width(of: render(edge, at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick], shutter: frame)))

        #expect(sharp <= 3)
        #expect(blurred > sharp + 3)
        // And the blurred frame is still opaque and keeps the edge's sides
        let image = render(edge, at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick], shutter: frame))
        #expect(image.pixel(at: CGPoint(x: 5, y: 150)) == [0, 0, 0, 255])
        #expect(image.pixel(at: CGPoint(x: 395, y: 150)) == [255, 255, 255, 255])
    }

    @Test func averagingKeepsAFlatFramesColorAndAlpha() {
        let flat = CIImage(color: CIColor(red: 0.2, green: 0.5, blue: 0.8)).cropped(to: bounds)
        let sharp = render(flat, at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick])).pixel(at: CGPoint(x: 200, y: 150))
        let blurred = render(flat, at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick], shutter: frame)).pixel(at: CGPoint(x: 200, y: 150))

        #expect(zip(sharp, blurred).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
    }

    @Test func aMovingCursorSpreadsAlongItsPathAndAStillOneDoesNot() {
        // Moves right at 100 pt (200 px) a second from (20, 50) pt: at 1 s, 240 px from the left and 200 up
        var moving = cursorTelemetry
        moving.cursor = (0...120).map { .init(time: Double($0) / 60, location: CGPoint(x: 20 + 100 * Double($0) / 60, y: 50)) }
        let style = CursorStyle(appearance: .dot, smoothing: .off)
        let black = CIImage(color: .black).cropped(to: bounds)

        // A shutter of 0.1 s covers 20 px: the 32 px dot reaches 10 px further ahead, where it's sharp without
        let sharp = render(black, at: 1, plan: plan(at: 5, cursorStyle: style, telemetry: moving))
        let blurred = render(black, at: 1, plan: plan(at: 5, cursorStyle: style, shutter: 0.1, telemetry: moving))
        #expect(sharp.pixel(at: CGPoint(x: 260, y: 200)) == [0, 0, 0, 255])
        #expect(blurred.pixel(at: CGPoint(x: 260, y: 200))[0] > 20)
        // And it's the same dot, less bright where the movement leaves it
        #expect(blurred.pixel(at: CGPoint(x: 240, y: 200))[0] > 60)

        // At rest, the same bytes
        let still = plan(at: 5, cursorStyle: style)
        let stillBlurred = plan(at: 5, cursorStyle: style, shutter: 0.1)
        #expect(bytes(of: drawn(black, at: 1, plan: still)) == bytes(of: drawn(black, at: 1, plan: stillBlurred)))
    }

    @Test func placementsAreOneWhenTheShutterIsClosedOrTheCameraStillAndMoreAcrossAMove() {
        #expect(FrameRenderer.placements(at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick])).count == 1)
        #expect(FrameRenderer.placements(at: 5, plan: plan(at: 0, zooms: [zoomOnClick], shutter: frame)).count == 1)

        let moving = FrameRenderer.placements(at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick], shutter: frame))
        #expect(moving.count == 8)
        // Zooming in, so each is a bigger magnification than the one before, and the middle is the frame's own
        #expect(zip(moving, moving.dropFirst()).allSatisfy { $0.a < $1.a })
        let centred = plan(at: 0, zooms: [zoomOnClick]).camera.viewport(at: 0.1).scale
        #expect(moving[0].a < centred && centred < moving[7].a)

        // A move of a few pixels is covered by fewer: this shutter is a fifth as long
        let slow = FrameRenderer.placements(at: 0.1, plan: plan(at: 0, zooms: [zoomOnClick], shutter: frame / 5))
        #expect((2..<8).contains(slow.count))

        // The preview's cap
        var preview = plan(at: 0, zooms: [zoomOnClick], shutter: frame)
        preview.maximumBlurSamples = 2
        #expect(FrameRenderer.placements(at: 0.1, plan: preview).count == 2)
    }
}
