//
//  MotionFrameRenderer+Design.swift
//  Reco
//

import CoreImage

/// Motion design's parts of a frame (spec 0014): the pointers clicks show, particles drawn sharp, and kinetic type's accent.
nonisolated extension MotionFrameRenderer {

    /// The pointers clicking `scene`'s layers at `time`, over them (spec 0014).
    static func pointers(of scene: MotionPlan.Scene, at time: Double, plan: MotionPlan) -> CIImage {
        guard let pointer = plan.pointer else { return .empty() }
        return clickTargets(of: scene, at: time, plan: plan).reduce(CIImage.empty()) { image, target in
            target.clicks.compactMap { pointer.image(of: $0, on: target.corners, at: time, canvas: plan.canvas, outputScale: plan.outputScale) }
                .reduce(image) { $1.composited(over: $0) }
        }
    }

    /// Where the tips of `scene`'s pointers are at `time`, click by click in the scene's order; `nil` for one not on screen.
    static func pointerTips(of scene: MotionPlan.Scene, at time: Double, plan: MotionPlan) -> [CGPoint?] {
        guard plan.pointer != nil else { return [] }
        return clickTargets(of: scene, at: time, plan: plan).flatMap { target in
            target.clicks.map { MotionPointer.tip(of: $0, on: target.corners, at: time, canvas: plan.canvas)?.point }
        }
    }

    /// The clicked layers' clicks and the quads they're clicked on at `time`: a group where its layers are, all of them (a
    /// button of a pill and its label).
    private static func clickTargets(of scene: MotionPlan.Scene, at time: Double, plan: MotionPlan) -> [(clicks: [MotionPlan.Click], corners: [CGPoint])] {
        guard scene.layers.contains(where: { !$0.clicks.isEmpty }) else { return [] }
        let placements = plan.placements(of: scene, at: time)
        return scene.layers.enumerated().compactMap { index, layer in
            guard !layer.clicks.isEmpty else { return nil }
            let points = placements.filter { scene.isLayer($0.layer, within: index) }.flatMap(\.corners)
            guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
            let corners = points.count == 4 ? points
                : [CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY), CGPoint(x: maxX, y: maxY), CGPoint(x: minX, y: maxY)]
            return (layer.clicks, corners)
        }
    }

    /// `placements` with the layers drawn sharp (a burst's particles) where they are at the frame's own time, `frame`.
    static func sharpened(_ placements: [MotionPlan.Placement], at frame: [MotionPlan.Placement], of scene: MotionPlan.Scene) -> [MotionPlan.Placement] {
        let sharp = Dictionary(frame.filter { scene.layers[$0.layer].isSharp }.map { ($0.layer, $0) }) { first, _ in first }
        return placements.compactMap { scene.layers[$0.layer].isSharp ? sharp[$0.layer] : $0 }
    }

    /// Kinetic typing's accent (spec 0014): the newest letters in it, fading to the text's colour over
    /// ``kineticTint`` s, behind a caret block in it from ``kineticCaretLead`` s before the first letter to
    /// ``kineticCaretHold`` s after the last.
    static func kinetic(_ shown: CIImage, image: CIImage, of layer: MotionPlan.Layer, by reveal: TextReveal, at time: Double) -> CIImage {
        guard let accent = layer.accent else { return shown }
        let (parts, pixels) = (layer.parts, { (rect: CGRect) in revealPixels(of: rect, in: layer) })
        var shown = shown
        let typed = parts.indices.filter { reveal.fraction(ofPart: $0, at: time) > 0 }
        for index in typed {
            let age = time - reveal.start(ofPart: index)
            guard age < kineticTint else { continue }
            let tinted = image.cropped(to: pixels(parts[index])).applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputBiasVector": CIVector(x: accent.red, y: accent.green, z: accent.blue, w: 0)
            ])
            shown = tinted.fading(to: 1 - age / kineticTint).composited(over: shown)
        }
        let last = typed.last
        let end = reveal.end(parts: parts.count) + kineticCaretHold
        guard reveal.start - kineticCaretLead <= time, time < end + 0.1, let box = last.map({ parts[$0] }) ?? parts.first else { return shown }
        // A block after the newest letter, 0.11 of its line wide, faded out over 0.1 s once it's held
        let line = box.height
        let caret = CGRect(x: (last == nil ? box.minX : box.maxX) + line * 0.04, y: box.minY + line * 0.1, width: line * 0.11, height: line * 0.8)
        let color = CIColor(red: accent.red, green: accent.green, blue: accent.blue, alpha: accent.alpha)
        let bar = CIImage(color: color).cropped(to: pixels(caret))
        return (time > end ? bar.fading(to: 1 - (time - end) / 0.1) : bar).composited(over: shown)
    }

    /// How long a kinetic letter stays in the accent, the caret after the last, and the caret before the first: a caret the
    /// scene before stretched out of a dot holds across the cut.
    static let kineticTint = 0.25
    static let kineticCaretHold = 0.6
    static let kineticCaretLead = 0.3
}
