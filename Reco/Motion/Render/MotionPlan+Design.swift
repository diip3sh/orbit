//
//  MotionPlan+Design.swift
//  Reco
//

import Foundation

/// What a plan knows of motion design's clicks (spec 0014).
nonisolated extension MotionPlan {

    /// A pointer clicking a layer: it presses at `press` and stays until `leaves`, seconds into the scene.
    struct Click: Equatable, Sendable {
        let press: Double
        let leaves: Double
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
