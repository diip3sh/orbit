//
//  MotionPlan+Design.swift
//  Reco
//

import CoreImage

/// What a plan knows of motion design's clicks and letters (spec 0014).
nonisolated extension MotionPlan {

    /// A pointer clicking a layer: it presses at `press` and stays until `leaves`, seconds into the scene.
    struct Click: Equatable, Sendable {
        let press: Double
        let leaves: Double

        /// A selection the press drags across, the pointer following its end (spec 0016).
        var sweep: TextSelection?
    }

    /// Whether the video is on a light ground: what goes behind a card over it dims less (spec 0016).
    var isLight: Bool {
        0.2126 * background.red + 0.7152 * background.green + 0.0722 * background.blue > 0.5
    }

    /// Whether any layer is clicked, so the plan needs the system's pointer.
    var hasClicks: Bool {
        scenes.contains { $0.layers.contains { !$0.clicks.isEmpty } }
    }
}

nonisolated extension MotionPlan.Scene {

    /// Whether layer `index` is `ancestor` or inside it.
    func isLayer(_ index: Int, within ancestor: Int) -> Bool {
        var current: Int? = index
        while let layer = current {
            if layer == ancestor {
                return true
            }
            current = layers[layer].parent
        }
        return false
    }
}

nonisolated extension MotionPlan.Layer {

    /// The room its letters spring through around it, in canvas pixels each side and whole image pixels: its revealed
    /// image is that much larger, drawn onto the quad around it.
    var revealRoom: CGSize {
        guard reveal?.style == .letter, let line = parts.map(\.height).max(), rasterScale > 0 else { return .zero }
        let room = { (lines: Double) in (line * lines * rasterScale).rounded(.up) / rasterScale }
        return CGSize(width: room(MotionFrameRenderer.letterRoom.width), height: room(MotionFrameRenderer.letterRoom.height))
    }
}
