//
//  MotionPlan+Grammar.swift
//  Reco
//

import CoreGraphics
import Foundation

// MARK: - Cameras and seams

extension MotionPlan {

    /// What a scene's camera moves do, from where its camera looks before them.
    nonisolated static func cameraMoves(_ moves: [MotionMove], of scene: Scene, context: MoveContext) -> [MotionProperty: [PropertyTrack]] {
        var context = context
        context.lookAt = CGPoint(x: scene.cameraBase[.positionX] ?? 0, y: scene.cameraBase[.positionY] ?? 0)
        return moves.reduce(into: [:]) { tracks, move in
            tracks.merge(MoveExpansion.effect(of: move, in: context).tracks) { $0 + $1 }
        }
    }

    /// Each seam's camera tracks on the scenes either side of it, and its transition.
    nonisolated static func addSeams(of document: MotionDocument, to scenes: inout [Scene]) {
        for index in scenes.indices.dropFirst() {
            let (before, after) = (document.scenes[index - 1], document.scenes[index])
            let effect = SeamExpansion.effect(
                of: after.seam, outgoingDuration: before.duration, canvas: document.canvas.size,
                hasText: hasText(before.layers) || hasText(after.layers), velocity: velocity(atEndOf: scenes[index - 1])
            )
            scenes[index - 1].cameraMoves.merge(effect.outgoing) { $0 + $1 }
            scenes[index].cameraMoves.merge(effect.incoming) { $0 + $1 }
            scenes[index].transition = effect.transition
            scenes[index - 1].overlap = effect.transition?.duration ?? 0
        }
    }

    /// The camera's speed over the scene's last 1/120 s.
    nonisolated private static func velocity(atEndOf scene: Scene) -> SeamExpansion.Velocity {
        let step = 1.0 / 120
        let (end, before) = (scene.duration, max(scene.duration - step, 0))
        let change = { (property: MotionProperty) in
            (scene.cameraValue(property, at: end) - scene.cameraValue(property, at: before)) / step
        }
        let zoom = (log(max(scene.cameraValue(.scale, at: end), 0.01)) - log(max(scene.cameraValue(.scale, at: before), 0.01))) / step
        return SeamExpansion.Velocity(horizontal: change(.positionX), vertical: change(.positionY), zoom: zoom)
    }

    nonisolated private static func hasText(_ layers: [MotionLayer]) -> Bool {
        layers.contains { layer in
            switch layer.content {
            case .text: true
            case .group(let children): hasText(children)
            default: false
            }
        }
    }
}
