//
//  MotionPointer.swift
//  Reco
//

import CoreImage
import ImageIO

/// The pointer a click shows (spec 0014): the system's arrow rising in from below, its pointing hand once it's over
/// what it clicks, pressing with it, then fading. Drawn over a scene's layers at its target's middle, wherever the
/// target has moved, as large as the camera shows the canvas (Lovable's macro shots: the hand as close as the pill it
/// presses). Measured on the Spotify Jam film: the arrow comes up from below the frame, fast and slowing, about
/// 0.3 s before it lands (0.76, 0.65 and 0.6 of the frame's height 0.2, 0.13 and 0.07 s before), blurred by its speed,
/// and turns to the hand on arrival; the hand is 8 % of the frame's height (46 of 576 px).
nonisolated struct MotionPointer: Sendable {

    let arrow: CursorShapeTrack.Sprite
    let hand: CursorShapeTrack.Sprite

    /// The hand's drawn height in points, without the clear margin its image has for its shadow.
    let handHeight: Double

    static let travel = 0.3

    /// It lands this long before its press.
    static let landing = 0.15

    static let fade = 0.25

    /// A press this early in its scene has the pointer there from the cut.
    static let carriedOver = 0.6

    /// The hand's drawn height as a share of the canvas's; the arrow at the same points to pixels.
    static let height = 0.08

    /// How far below the target's middle its tip lands, as a share of the target's height on screen.
    static let tipBelow = 0.22

    /// A press shrinks the hand by this much and back over 0.2 s.
    static let pressDepth = 0.15

    /// The running system's arrow and pointing hand, read on the main actor where `NSCursor` lives.
    static func system() async -> MotionPointer? {
        let (arrow, hand) = await MainActor.run { (StandardCursors.arrowSprite, StandardCursors.sprite(of: .pointingHand, id: 1)) }
        let pointing = hand ?? arrow
        guard let arrowSprite = CursorShapeTrack.Sprite(arrow), let handSprite = CursorShapeTrack.Sprite(pointing) else { return nil }
        let drawn = drawnRows(of: pointing.png) ?? handSprite.image.extent.height
        return MotionPointer(arrow: arrowSprite, hand: handSprite, handHeight: drawn * handSprite.pointsPerPixel)
    }

    /// How many rows of a PNG's pixels are drawn: its height without the clear rows above and below.
    private static func drawnRows(of png: Data) -> Double? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else { return nil }
        let alpha = data.bindMemory(to: UInt8.self, capacity: image.width * image.height)
        let drawn = (0..<image.height).filter { row in (0..<image.width).contains { alpha[row * image.width + $0] > 24 } }
        return drawn.first.flatMap { first in drawn.last.map { Double($0 - first + 1) } }
    }

    /// When the pointer of `click` comes on: a travel before it lands. A press early in its shot was carried over the cut:
    /// Lovable's hand is on the pill as its macro cuts in.
    static func appears(_ click: MotionPlan.Click) -> Double {
        (click.press < carriedOver ? -1 : click.press - landing) - travel
    }

    /// Where the pointer of `click` on a layer whose quad is `corners` (canvas points, top-left origin) has its tip at `time`
    /// in the scene, and how opaque it is; `nil` while it isn't on screen. It travels in from `from`, where the scene's
    /// pointer was for the click before, or else from below the frame.
    static func tip(
        of click: MotionPlan.Click, on corners: [CGPoint], at time: Double, canvas: CGSize, from: CGPoint? = nil
    ) -> (point: CGPoint, opacity: Double)? {
        let appears = appears(click)
        let lands = appears + travel
        guard corners.count == 4, time >= appears, time <= click.leaves + fade else { return nil }
        let middle = CGPoint(x: corners.map(\.x).reduce(0, +) / 4, y: corners.map(\.y).reduce(0, +) / 4)
        let onScreen = hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y)
        // A drag's tip is on the selection's end, wherever it has got to (the start before its press)
        let target = click.sweep.map { point(at: $0.tip(at: time), on: corners) } ?? CGPoint(x: middle.x, y: middle.y + tipBelow * onScreen)
        if time < lands {
            // From just below the frame, so it needs no fade
            let progress = MotionEasing.enter.progress((time - appears) / travel, duration: travel)
            let start = from ?? CGPoint(x: target.x + 0.02 * canvas.width, y: max(canvas.height * 1.02, target.y + 0.2 * canvas.height))
            return (CGPoint(x: start.x + (target.x - start.x) * progress, y: start.y + (target.y - start.y) * progress), 1)
        }
        guard time > click.leaves else { return (target, 1) }
        let gone = (time - click.leaves) / fade
        return gone < 1 ? (CGPoint(x: target.x, y: target.y + 0.03 * canvas.height * gone), 1 - gone) : nil
    }

    /// The point `fraction` of the way across and down a quad's corners (top-left, top-right, bottom-right, bottom-left).
    private static func point(at fraction: CGPoint, on corners: [CGPoint]) -> CGPoint {
        let mix = { (start: CGPoint, end: CGPoint, share: Double) in CGPoint(x: start.x + (end.x - start.x) * share, y: start.y + (end.y - start.y) * share) }
        return mix(mix(corners[0], corners[1], fraction.x), mix(corners[3], corners[2], fraction.x), fraction.y)
    }

    /// The pointer of `click` on a layer whose quad is `corners` (canvas points, top-left origin) at `time` in the
    /// scene, in output pixels from the bottom-left; `nil` while it isn't on screen.
    func image(
        of click: MotionPlan.Click, on corners: [CGPoint], at time: Double, canvas: CGSize, outputScale: Double, magnification: Double = 1,
        from: CGPoint? = nil
    ) -> CIImage? {
        guard let (position, opacity) = Self.tip(of: click, on: corners, at: time, canvas: canvas, from: from) else { return nil }
        // The arrow rising in from below; handed on from a press, it stays the hand, as Lovable's moving down its menu
        // A drag across text is the arrow throughout, as IrukaDark's was
        let sprite = click.sweep != nil || (from == nil && time < click.press - Self.landing - 0.05 && click.press >= Self.carriedOver) ? arrow : hand
        let pressing = time - (click.press - 0.04)
        let press = pressing > 0 && pressing < 0.2 ? 1 - Self.pressDepth * sin(.pi * pressing / 0.2) : 1
        // Both sprites at the hand's points to pixels, so the arrow is the hand's size as on screen
        let pixels = Self.height * canvas.height / handHeight * sprite.pointsPerPixel * outputScale * press * magnification
        let placement = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
            .concatenating(CGAffineTransform(scaleX: pixels, y: pixels))
            .concatenating(CGAffineTransform(translationX: position.x * outputScale, y: (canvas.height - position.y) * outputScale))
        let image = sprite.image.transformed(by: placement, highQualityDownsample: true)
        return opacity < 1 ? image.fading(to: opacity) : image
    }
}
