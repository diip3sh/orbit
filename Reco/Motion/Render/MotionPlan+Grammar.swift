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

    /// Each seam's camera tracks on the scenes either side of it, and its transition; the scenes breathe first.
    nonisolated static func addSeams(of document: MotionDocument, to scenes: inout [Scene]) {
        breathe(&scenes, of: document)
        if let first = scenes.first, let opening = document.scenes.first, let arrival = SeamExpansion.arrival(on: first.field) {
            if opening.shot?.kind == .macro {
                scenes[0].arrival = language(arrival, into: first.field, document: document)
            } else if opening.seam == arrival.seam {
                scenes[0].arrival = language(arrival, into: first.field, document: document)
                scenes[0].arrivesAt = MotionFrameRenderer.groundSwell
            }
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
            var transition = effect.transition.map { language($0, into: scenes[index].field, document: document) }
            if after.seam == .fade, document.isEditorial {
                transition = SeamExpansion.Transition(seam: .fade, duration: SeamExpansion.darkenDuration, easing: .enter)
            }
            if MotionSeam.graphic.contains(after.seam) {
                let grounds = [before, after].compactMap { ground(of: $0, in: document) }
                transition?.colors = document.style.seamColors(between: grounds, background: document.canvas.background)
                transition?.variant = index
                transition?.isLight = MotionPlan.isLight(document.canvas.background)
            }
            scenes[index].transition = transition
            scenes[index - 1].overlap = transition?.duration ?? 0
        }
    }

    /// Every scene without a camera of its own, or a shot that lays one out, breathes (``MoveExpansion/breath(over:)``), all but
    /// the last, which holds as ElevenLabs' end card did. Editorial films first (spec 0018); then all (spec 0019): a LemonLime
    /// film whose agent gave its scenes no camera was still in a quarter of its frames before its end card.
    nonisolated private static func breathe(_ scenes: inout [Scene], of document: MotionDocument) {
        for index in scenes.indices.dropLast() {
            let scene = document.scenes[index]
            guard scene.shot == nil, scene.camera.moves.isEmpty, scene.camera.keyframes.isEmpty else { continue }
            scenes[index].cameraMoves[.scale, default: []] += MoveExpansion.breath(over: scenes[index].duration)
        }
    }

    /// A seam drawn in a field's language takes the next scene's field when it's of the seam's family,
    /// else the family's first pick, coloured from the brand as that field is; a melt, the haze's colours.
    nonisolated private static func language(_ transition: SeamExpansion.Transition, into field: MotionField, document: MotionDocument) -> SeamExpansion.Transition {
        var transition = transition
        // A melt's front is in the brand's colours, as the haze's light is
        if transition.seam == .melt {
            transition.palette = FieldPalette(.haze, style: document.style, background: document.canvas.background)
        }
        guard let family = transition.seam.family else { return transition }
        transition.look = field.family == family ? field : MotionField.allCases.first { $0.family == family } ?? .plain
        transition.palette = FieldPalette(transition.look, style: document.style, background: document.canvas.background)
        return transition
    }

    /// The colour a scene's frame mostly is, when it can be told: the topmost filled rectangle covering the canvas, else a plain
    /// field's background.
    nonisolated private static func ground(of scene: MotionScene, in document: MotionDocument) -> RGBAColor? {
        let canvas = document.canvas.size
        let covering = scene.layers.last { layer in
            guard case .shape(let shape) = layer.content, shape.kind == .rectangle, (shape.stroke ?? 0) == 0, shape.glass != true,
                  shape.picture == nil else { return false }
            return shape.size.width >= canvas.width * 0.95 && shape.size.height >= canvas.height * 0.95
        }
        if case .shape(let shape) = covering?.content {
            return shape.color
        }
        return (scene.field ?? document.canvas.field) == .plain ? document.canvas.background : nil
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
