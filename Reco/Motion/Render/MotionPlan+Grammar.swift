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
        return zip(moves, MoveExpansion.cameraContexts(of: moves, from: context)).reduce(into: [:]) { tracks, move in
            tracks.merge(MoveExpansion.effect(of: move.0, in: move.1).tracks) { $0 + $1 }
        }
    }

    /// Each seam's camera tracks on the scenes either side of it, and its transition.
    nonisolated static func addSeams(of document: MotionDocument, to scenes: inout [Scene]) {
        if let first = scenes.first, document.scenes.first?.shot?.kind == .macro {
            scenes[0].arrival = SeamExpansion.arrival(on: first.field).map { language($0, into: first.field, document: document) }
        }
        for index in scenes.indices.dropFirst() {
            let (before, after) = (document.scenes[index - 1], document.scenes[index])
            let canvas = document.canvas.size
            let effect = SeamExpansion.effect(
                of: after.seam, outgoingDuration: before.duration, canvas: canvas,
                hasText: hasText(before.layers) || hasText(after.layers), velocity: velocity(atEndOf: scenes[index - 1]),
                zooms: (magnification(of: scenes[index - 1], at: before.duration, canvas: canvas), magnification(of: scenes[index], at: 0, canvas: canvas))
            )
            scenes[index - 1].cameraMoves.merge(effect.outgoing) { $0 + $1 }
            scenes[index].cameraMoves.merge(effect.incoming) { $0 + $1 }
            scenes[index].transition = effect.transition.map { language($0, into: scenes[index].field, document: document) }
            scenes[index - 1].overlap = effect.transition?.duration ?? 0
        }
    }

    /// A seam drawn in a field's language takes the next scene's field when it's of the seam's family,
    /// else the family's first pick, coloured from the brand as that field is.
    nonisolated private static func language(_ transition: SeamExpansion.Transition, into field: MotionField, document: MotionDocument) -> SeamExpansion.Transition {
        guard let family = transition.seam.family else { return transition }
        var transition = transition
        transition.look = field.family == family ? field : MotionField.allCases.first { $0.family == family } ?? .plain
        transition.palette = FieldPalette(transition.look, accent: document.style.accent, background: document.canvas.background)
        return transition
    }

    /// How many times larger than from rest the camera shows the canvas.
    nonisolated private static func magnification(of scene: Scene, at time: Double, canvas: CGSize) -> Double {
        CameraProjection(
            lookAt: .zero, dolly: scene.cameraValue(.positionZ, at: time), canvas: canvas, zoom: max(scene.cameraValue(.scale, at: time), 0.01)
        ).magnification
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
