//
//  MotionPointer.swift
//  Reco
//

import CoreImage
import ImageIO

/// The pointer a click shows (spec 0014): the system's arrow rising in from below, its pointing hand once it's over
/// what it clicks, pressing with it, then fading. Drawn over a scene's layers at its target's middle, wherever the
/// target has moved. Measured on the Spotify Jam film: the arrow rises in about 0.5 s and turns to the hand on
/// arrival; the hand is 8 % of the frame's height (46 of 576 px).
nonisolated struct MotionPointer: Sendable {

    let arrow: CursorShapeTrack.Sprite
    let hand: CursorShapeTrack.Sprite

    /// The hand's drawn height in points, without the clear margin its image has for its shadow.
    let handHeight: Double

    static let travel = 0.5

    /// It lands this long before its press.
    static let landing = 0.15

    static let fade = 0.25

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

    /// The pointer of `click` on a layer whose quad is `corners` (canvas points, top-left origin) at `time` in the
    /// scene, in output pixels from the bottom-left; `nil` while it isn't on screen.
    func image(of click: MotionPlan.Click, on corners: [CGPoint], at time: Double, canvas: CGSize, outputScale: Double) -> CIImage? {
        let lands = click.press - Self.landing
        let appears = lands - Self.travel
        guard corners.count == 4, time >= appears, time <= click.leaves + Self.fade else { return nil }
        let middle = CGPoint(x: corners.map(\.x).reduce(0, +) / 4, y: corners.map(\.y).reduce(0, +) / 4)
        let onScreen = hypot(corners[3].x - corners[0].x, corners[3].y - corners[0].y)
        let tip = CGPoint(x: middle.x, y: middle.y + Self.tipBelow * onScreen)
        var position = tip
        var opacity = min((time - appears) / 0.1, 1)
        if time < lands {
            let progress = MotionEasing.move.progress((time - appears) / Self.travel, duration: Self.travel)
            let start = CGPoint(x: tip.x + 0.04 * canvas.width, y: tip.y + 0.3 * canvas.height)
            position = CGPoint(x: start.x + (tip.x - start.x) * progress, y: start.y + (tip.y - start.y) * progress)
        } else if time > click.leaves {
            let gone = (time - click.leaves) / Self.fade
            opacity *= 1 - gone
            position.y += 0.03 * canvas.height * gone
        }
        guard opacity > 0 else { return nil }
        let sprite = time < lands - 0.05 ? arrow : hand
        let pressing = time - (click.press - 0.04)
        let press = pressing > 0 && pressing < 0.2 ? 1 - Self.pressDepth * sin(.pi * pressing / 0.2) : 1
        // Both sprites at the hand's points to pixels, so the arrow is the hand's size as on screen
        let pixels = Self.height * canvas.height / handHeight * sprite.pointsPerPixel * outputScale * press
        let placement = CGAffineTransform(translationX: -sprite.hotspot.x, y: -sprite.hotspot.y)
            .concatenating(CGAffineTransform(scaleX: pixels, y: pixels))
            .concatenating(CGAffineTransform(translationX: position.x * outputScale, y: (canvas.height - position.y) * outputScale))
        let image = sprite.image.transformed(by: placement, highQualityDownsample: true)
        return opacity < 1 ? image.fading(to: opacity) : image
    }
}
