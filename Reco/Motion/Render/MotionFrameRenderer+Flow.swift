//
//  MotionFrameRenderer+Flow.swift
//  Reco
//

import CoreImage

/// Flow films' parts of a frame (spec 0016): a text's selection behind it.
nonisolated extension MotionFrameRenderer {

    /// A text layer's pixels as its reveal shows them at `time`, over its selection.
    static func lettered(_ content: CIImage, of layer: MotionPlan.Layer, at time: Double) -> CIImage {
        var content = content
        if let reveal = layer.reveal {
            content = revealed(content, of: layer, by: reveal, at: time)
        }
        if let selection = layer.clicks.lazy.compactMap(\.sweep).first {
            content = selected(content, of: layer, by: selection, at: time)
        }
        return content
    }

    /// A text layer's pixels over its selection at `time`: a box a line in the selection's colour, a little taller than its
    /// letters.
    static func selected(_ content: CIImage, of layer: MotionPlan.Layer, by selection: TextSelection, at time: Double) -> CIImage {
        let boxes = selection.boxes(at: time)
        guard !boxes.isEmpty else { return content }
        let color = CIImage(color: ciColor(selection.color))
        return content.composited(over: boxes.reduce(CIImage.empty()) { color.cropped(to: revealPixels(of: $1, in: layer)).composited(over: $0) })
    }
}
