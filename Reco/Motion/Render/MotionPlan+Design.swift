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

    /// Registration marks round a layer (spec 0017): when they show, seconds into its scene, and their colour, else ink on a
    /// light ground and white on a dark one.
    struct Marks: Equatable, Sendable {
        let shown: ClosedRange<Double>
        let color: RGBAColor?
    }

    /// A text eaten from both ends into a block by two bars in `color` (spec 0018), seconds into its scene.
    struct Eat: Equatable, Sendable {
        let start: Double
        let duration: Double
        let color: RGBAColor
    }

    /// Whether the video is on a light ground: what goes behind a card over it dims less (spec 0016).
    var isLight: Bool {
        Self.isLight(RGBAColor(red: background.red, green: background.green, blue: background.blue, alpha: 1))
    }

    /// Whether `color` is a light ground: its luminance past half.
    static func isLight(_ color: RGBAColor) -> Bool {
        0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue > 0.5
    }

    /// Whether the video is an editorial film, over paper, ink or pictures (spec 0017).
    var isEditorial: Bool {
        scenes.contains { $0.field.family == .editorial }
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
        guard reveal?.style == .letter || eat != nil, let line = parts.map(\.height).max(), rasterScale > 0 else { return .zero }
        let room = { (lines: Double) in (line * lines * rasterScale).rounded(.up) / rasterScale }
        // Eating bars start just outside the text's ends
        let lines = reveal?.style == .letter ? MotionFrameRenderer.letterRoom : CGSize(width: MoveExpansion.eatGap + MoveExpansion.eatBar.width, height: 0)
        return CGSize(width: room(lines.width), height: room(lines.height))
    }
}
