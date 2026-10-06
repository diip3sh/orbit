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

    /// A layer showing a live take, and its scene's time on the video.
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
                    LiveLayer(key: LayerKey(scene: sceneIndex, layer: index), live: $0, sceneStart: scene.start, sceneDuration: scene.duration)
                }
            }
        }
    }
}
