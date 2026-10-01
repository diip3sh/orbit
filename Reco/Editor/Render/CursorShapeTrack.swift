//
//  CursorShapeTrack.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import CoreImage
import Foundation
import ImageIO

/// Which image the editor draws for the cursor over time, with the images decoded once per plan.
nonisolated struct CursorShapeTrack: Sendable {

    /// A cursor image at its recorded resolution, and what places it.
    nonisolated struct Sprite: Sendable {
        let image: CIImage

        /// The click point in the image's pixels, from its bottom-left corner.
        let hotspot: CGPoint

        /// The image's size in points per pixel.
        let pointsPerPixel: CGFloat
    }

    /// Shapes shown for less than this are dropped, like the I-beam flashing as the cursor crosses
    /// a text field. Shapes are sampled at 15 Hz, so a shape seen once lasts under 133 ms.
    static let minimumDuration = 0.15

    /// No cursor.
    static let none = CursorShapeTrack(sprites: [], changes: [])

    private let sprites: [Sprite]

    /// When the cursor switched to each of ``sprites``. Each applies until the next; the first
    /// also before its time.
    private let changes: [(time: Double, sprite: Int)]

    private init(sprites: [Sprite], changes: [(time: Double, sprite: Int)]) {
        self.sprites = sprites
        self.changes = changes
    }

    /// - Parameters:
    ///   - duration: The recording's length in seconds.
    ///   - arrow: Drawn when the telemetry has no shapes, e.g. `NSCursor.currentSystem` returned
    ///     nothing while recording.
    init(telemetry: InputTelemetry, duration: Double, arrow: InputTelemetry.CursorSprite?) {
        var sprites: [Sprite] = []
        var indices: [Int: Int] = [:]
        for sprite in telemetry.cursorSprites {
            guard let decoded = Sprite(sprite) else { continue }
            indices[sprite.id] = sprites.count
            sprites.append(decoded)
        }

        var changes = Self.steadyShapes(telemetry.cursorShapes, duration: duration).compactMap { shape in
            indices[shape.sprite].map { (shape.time, $0) }
        }
        if changes.isEmpty, let arrow = arrow.flatMap(Sprite.init) {
            changes = [(0, sprites.count)]
            sprites.append(arrow)
        }
        self.init(sprites: sprites, changes: changes)
    }

    /// The image shown at source time `time`, or `nil` when there's none.
    func sprite(at time: Double) -> Sprite? {
        guard !changes.isEmpty else { return nil }
        return sprites[changes[max(changes.partitioningIndex { $0.time > time } - 1, 0)].sprite]
    }

    /// The track with its images in `range`'s encoding (see ``OverlayImages/encoded(_:in:)``).
    func encoded(in range: DynamicRange) -> CursorShapeTrack {
        let sprites = sprites.map { Sprite(image: OverlayImages.encoded($0.image, in: range), hotspot: $0.hotspot, pointsPerPixel: $0.pointsPerPixel) }
        return CursorShapeTrack(sprites: sprites, changes: changes)
    }

    /// `shapes` without those shown for less than ``minimumDuration`` and the repeats that leaves.
    /// A recording that only ever shows brief shapes keeps its first.
    static func steadyShapes(_ shapes: [InputTelemetry.CursorShape], duration: Double) -> [InputTelemetry.CursorShape] {
        var steady: [InputTelemetry.CursorShape] = []
        for (index, shape) in shapes.enumerated() {
            let end = index + 1 < shapes.count ? shapes[index + 1].time : duration
            guard end - shape.time >= minimumDuration, shape.sprite != steady.last?.sprite else { continue }
            steady.append(shape)
        }
        return steady.isEmpty ? Array(shapes.prefix(1)) : steady
    }
}

nonisolated extension CursorShapeTrack.Sprite {

    /// Decodes the recorded image, or `nil` when it can't be.
    init?(_ sprite: InputTelemetry.CursorSprite) {
        // Decoded now rather than on every frame
        guard sprite.size.width > 0,
              let source = CGImageSourceCreateWithData(sprite.png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { return nil }
        let pixelsPerPoint = CGFloat(image.width) / sprite.size.width
        self.image = CIImage(cgImage: image)
        hotspot = CGPoint(x: sprite.hotspot.x * pixelsPerPoint, y: CGFloat(image.height) - sprite.hotspot.y * pixelsPerPoint)
        pointsPerPixel = 1 / pixelsPerPoint
    }
}
