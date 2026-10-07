//
//  MotionPlan+Live.swift
//  Reco
//

import CoreGraphics
import CoreImage
import Foundation

nonisolated extension MotionPlan {

    /// A layer of a scene, by index: how the composition names the frames it supplies.
    nonisolated struct LayerKey: Hashable, Sendable {
        let scene: Int
        let layer: Int
    }

    /// A live take on a layer. Its frames come from the composition, which plays the movie from the
    /// start of the layer's scene; its cursor is drawn into them, so it turns with the plane.
    nonisolated struct Live: Sendable {
        let asset: String
        let movie: URL

        /// Seconds; the last frame holds after it.
        let duration: Double

        /// The element's corner radius in the movie's pixels.
        let radius: Double

        /// What of the movie shows: the element's painted shape at the movie's size, its alpha
        /// the mask; `nil` for a take without one, cut to ``radius``.
        let matte: CIImage?

        /// The take's cursor, in its whole video's pixels; `nil` when it has none.
        let cursor: CursorPath?
        let cursorShapes: CursorShapeTrack

        /// Where the movie's bottom-left corner is in the take's whole video, in Core Image pixels:
        /// the movie is the element's box, the telemetry the viewport's.
        let origin: CGPoint

        init(_ take: UILiftCache.Take, asset: String) {
            let info = take.info
            let scale = Double(info.scale)
            let videoHeight = take.telemetry.capture.videoSize.height
            let drawn = RenderPlan.drawnCursor(for: take.telemetry, style: CursorStyle(), duration: info.duration, videoHeight: videoHeight, arrow: nil)
            self.asset = asset
            movie = take.movie
            duration = info.duration
            radius = info.radius * scale
            // Stretched to the movie, whose box is the element's rounded out to whole CSS pixels
            matte = take.matte.flatMap { CIImage(contentsOf: $0) }.map { image in
                image.transformed(by: CGAffineTransform(
                    scaleX: info.crop.width * scale / image.extent.width, y: info.crop.height * scale / image.extent.height
                ))
            }
            cursor = drawn?.path
            cursorShapes = drawn?.shapes ?? .none
            origin = CGPoint(x: info.crop.minX * scale, y: videoHeight - info.crop.maxY * scale)
        }
    }

    /// A layer showing a live take, and its scene's time on the video, with the overlap under the
    /// next scene's transition.
    nonisolated struct LiveLayer: Sendable {
        let key: LayerKey
        let live: Live
        let sceneStart: Double
        let sceneDuration: Double
    }

    /// Every layer that shows a live take.
    var liveLayers: [LiveLayer] {
        scenes.enumerated().flatMap { sceneIndex, scene in
            scene.layers.enumerated().compactMap { index, layer in
                layer.live.map {
                    LiveLayer(key: LayerKey(scene: sceneIndex, layer: index), live: $0, sceneStart: scene.start, sceneDuration: scene.duration + scene.overlap)
                }
            }
        }
    }

    /// Video pixels per CSS pixel for a live layer `width` canvas pixels wide drawn at
    /// `rasterScale`: whole, at most 8×, and the movie within HEVC's 8,192 px. A take recorded at
    /// 2× and shown at four times its CSS size on a 4K canvas read soft.
    static func takeScale(for info: UILiftCache.TakeInfo, width: Double, rasterScale: Double) -> Int {
        let scale = Int((rasterScale * width / info.crop.width - 0.01).rounded(.up))
        let fits = Int(UILiftCache.maximumMovieSide / max(info.crop.width, info.crop.height))
        return max(min(scale, UILiftCache.maximumScale, fits), 1)
    }

    /// Image pixels per CSS pixel for a `ui` layer `width` canvas pixels wide drawn at
    /// `rasterScale`, past 8× only while the lift fits ``UILiftCache/maximumLiftSide``; 2× before the
    /// first lift, when the element's size isn't known yet.
    static func liftScale(for lift: UILiftCache.Lift?, width: Double, rasterScale: Double) -> Int {
        guard let lift else { return 2 }
        // Not a scale up for a rounding error
        let scale = Int((rasterScale * width / lift.size.width - 0.01).rounded(.up))
        let fits = Int(UILiftCache.maximumLiftSide / max(lift.size.width, lift.size.height, 1))
        return min(max(scale, UILiftCache.scales.lowerBound), max(UILiftCache.maximumScale, fits), UILiftCache.scales.upperBound)
    }
}
