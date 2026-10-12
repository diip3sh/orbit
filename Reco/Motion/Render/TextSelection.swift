//
//  TextSelection.swift
//  Reco
//

import CoreGraphics

/// A text's selection swept across it (``MotionMove/Kind/select``): part by part from its first to its last, a box a line,
/// as a pointer dragging across it selects. Held once it's done, till the scene ends.
nonisolated struct TextSelection: Equatable, Sendable {

    /// The text's characters (or words), in the layer's canvas pixels from its top-left, and the layer's size.
    let parts: [CGRect]
    let size: CGSize
    let start: Double
    let duration: Double
    let color: RGBAColor

    /// The macOS selection's light blue, as IrukaDark's error was selected.
    static let defaultColor = RGBAColor(red: 0.62, green: 0.84, blue: 0.97, alpha: 1)

    /// How many parts are selected at `time`, the last partly: eased in and out, as a hand drags.
    func reach(at time: Double) -> Double {
        let progress = min(max((time - start) / duration, 0), 1)
        return MotionEasing.move.progress(progress, duration: duration) * Double(parts.count)
    }

    /// What's selected at `time`, a box a line.
    func boxes(at time: Double) -> [CGRect] {
        let reach = reach(at: time)
        guard reach > 1e-6 else { return [] }
        var lines: [CGRect] = []
        for (index, part) in parts.enumerated() where Double(index) < reach {
            let box = CGRect(x: part.minX, y: part.minY, width: part.width * min(reach - Double(index), 1), height: part.height)
            if let last = lines.last, abs(last.midY - box.midY) < box.height / 2 {
                lines[lines.count - 1] = last.union(box)
            } else {
                lines.append(box)
            }
        }
        return lines
    }

    /// Where the dragging pointer's tip is at `time`, in fractions of the layer: the selection's end, a little below the middle
    /// of its line; before it starts, the first part's start.
    func tip(at time: Double) -> CGPoint {
        guard let first = parts.first, size.width > 0, size.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let box = boxes(at: time).last ?? CGRect(x: first.minX, y: first.minY, width: 0, height: first.height)
        return CGPoint(x: box.maxX / size.width, y: (box.minY + 0.6 * box.height) / size.height)
    }
}
