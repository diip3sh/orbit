//
//  MotionFrameRenderer+Design.swift
//  Reco
//

import CoreImage

/// Motion design's parts of a frame (spec 0014): the pointers clicks show, and kinetic type's accent.
nonisolated extension MotionFrameRenderer {

    /// The pointers clicking `scene`'s layers at `time`, over them (spec 0014). A group is clicked where its layers
    /// are, all of them: a button of a pill and its label.
    static func pointers(of scene: MotionPlan.Scene, at time: Double, plan: MotionPlan) -> CIImage {
        guard let pointer = plan.pointer, scene.layers.contains(where: { !$0.clicks.isEmpty }) else { return .empty() }
        let placements = plan.placements(of: scene, at: time)
        var image = CIImage.empty()
        for (index, layer) in scene.layers.enumerated() where !layer.clicks.isEmpty {
            let points = placements.filter { scene.isLayer($0.layer, within: index) }.flatMap(\.corners)
            guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { continue }
            let corners = points.count == 4 ? points
                : [CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY), CGPoint(x: maxX, y: maxY), CGPoint(x: minX, y: maxY)]
            for click in layer.clicks {
                guard let drawn = pointer.image(of: click, on: corners, at: time, canvas: plan.canvas, outputScale: plan.outputScale) else { continue }
                image = drawn.composited(over: image)
            }
        }
        return image
    }

    /// Kinetic typing's accent (spec 0014): the newest letters in it, fading to the text's colour over
    /// ``kineticTint`` s, behind a caret block in it that goes ``kineticCaretHold`` s after the last letter.
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
        guard reveal.start <= time, time < end + 0.1, let box = last.map({ parts[$0] }) ?? parts.first else { return shown }
        // A block after the newest letter, 0.11 of its line wide, faded out over 0.1 s once it's held
        let line = box.height
        let caret = CGRect(x: (last == nil ? box.minX : box.maxX) + line * 0.04, y: box.minY + line * 0.1, width: line * 0.11, height: line * 0.8)
        let color = CIColor(red: accent.red, green: accent.green, blue: accent.blue, alpha: accent.alpha)
        let bar = CIImage(color: color).cropped(to: pixels(caret))
        return (time > end ? bar.fading(to: 1 - (time - end) / 0.1) : bar).composited(over: shown)
    }

    /// How long a kinetic letter stays in the accent, and the caret after the last.
    static let kineticTint = 0.25
    static let kineticCaretHold = 0.6
}
