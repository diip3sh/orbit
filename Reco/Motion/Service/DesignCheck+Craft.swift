//
//  DesignCheck+Craft.swift
//  Reco
//

import CoreGraphics

/// What made films read as basic next to the launch films they learned from (spec 0020): the product small in an empty
/// frame.
nonisolated extension DesignCheck {

    /// What a scene shows mid-way must reach this share of the frame's width or of its height: Cardboard's second film showed
    /// a 600 px line, a 1190 px box and 640 px cards on a black 1920 × 1080 frame, where launch films fill or crop it.
    static let leastSpan = (width: 0.5, height: 0.45)

    /// The scenes of `plan` (named by `scenes`) whose shown layers, all together, span less than ``leastSpan`` mid-way, the end
    /// card aside.
    static func smallContent(in plan: MotionPlan, scenes: [String]) -> [String] {
        zip(plan.scenes, scenes).dropLast().compactMap { scene, id in
            let points = plan.placements(of: scene, at: scene.duration / 2).filter { $0.opacity >= 0.5 }.flatMap(\.corners)
            guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
                  let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
            let (width, height) = ((min(maxX, plan.canvas.width) - max(minX, 0)) / plan.canvas.width, (min(maxY, plan.canvas.height) - max(minY, 0)) / plan.canvas.height)
            guard width < leastSpan.width, height < leastSpan.height else { return nil }
            return "\(id) shows \(Int((width * 100).rounded()))% of the frame's width: fill it (type twice the size, the UI larger, a "
                + "close shot cropped by the frame, more around it)."
        }
    }
}
