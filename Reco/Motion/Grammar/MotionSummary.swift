//
//  MotionSummary.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A motion document as `edit_motion` reports it to an agent: every scene with the layers its shot
/// lays out (their ids are what `set_moves` targets) and when each move runs, and what the
/// grammar's rules find. JSON, keys in snake case like the other tools'.
nonisolated struct MotionSummary: Encodable, Equatable, Sendable {
    var bundle: String
    var duration: Double
    var frameRate: Int
    var pacing: MotionCanvas.Pacing
    var assets: [Asset]
    var scenes: [Scene]
    var findings: [Finding]

    nonisolated struct Asset: Encodable, Equatable, Sendable {
        var id: String
        var live: Bool

        /// The element's size in CSS pixels, once captured.
        var size: CGSize?
    }

    nonisolated struct Scene: Encodable, Equatable, Sendable {
        var id: String

        /// Seconds from the video's start.
        var start: Double
        var duration: Double
        var seam: MotionSeam

        /// What it's drawn over: its own field, or the canvas's.
        var field: MotionField
        var shot: MotionShot?
        var layers: [Layer]
        var camera: [Move]
    }

    nonisolated struct Layer: Encodable, Equatable, Sendable {
        var id: String

        /// `text`, `ui`, `image`, `shape` or `group`.
        var kind: String
        var text: String?
        var asset: String?

        /// Laid out by the scene's shot: its moves can be set, the layer itself changes with the shot.
        var fromShot: Bool
        var moves: [Move]
        var layers: [Layer]?

        // swiftlint:disable:next nesting - the wire name differs
        private enum CodingKeys: String, CodingKey {
            case fromShot = "from_shot"
            case id, kind, text, asset, moves, layers
        }
    }

    /// A move as the document has it, and the seconds into its scene it runs.
    nonisolated struct Move: Encodable, Equatable, Sendable {
        var move: MotionMove
        var starts: Double
        var ends: Double
    }

    nonisolated struct Finding: Encodable, Equatable, Sendable {
        var rule: String
        var scene: String
        var layer: String?
        var message: String
    }

    /// - Parameter sizes: The assets' sizes in CSS pixels, for those captured.
    init(_ document: MotionDocument, bundle: URL, sizes: [String: CGSize]) {
        self.bundle = bundle.path(percentEncoded: false)
        duration = document.duration
        frameRate = document.canvas.frameRate
        pacing = document.canvas.pacing
        assets = document.assets.map { Asset(id: $0.id, live: $0.steps != nil, size: sizes[$0.id]) }
        var start = 0.0
        scenes = document.scenes.indices.map { index in
            let source = document.scenes[index]
            let scene = DocumentExpansion.laidOut(document, scene: index, sizes: sizes)
            defer { start += scene.duration }
            let shotIDs = Set(scene.layers.map(\.id)).subtracting(source.layers.map(\.id))
            var camera = MoveContext(sceneDuration: scene.duration, canvas: document.canvas.size)
            camera.lookAt = CGPoint(x: scene.camera.base(.positionX, canvas: document.canvas.size), y: scene.camera.base(.positionY, canvas: document.canvas.size))
            return Scene(
                id: scene.id, start: start, duration: scene.duration, seam: scene.seam, field: scene.field ?? document.canvas.field, shot: scene.shot,
                layers: scene.layers.map { Self.layer($0, fromShot: shotIDs.contains($0.id), in: scene, canvas: document.canvas.size) },
                camera: scene.camera.moves.map { Self.move($0, in: camera) }
            )
        }
        findings = MotionLint.findings(in: document, sizes: sizes).map {
            Finding(rule: $0.rule.rawValue, scene: $0.scene, layer: $0.layer, message: $0.message)
        }
    }

    private static func layer(_ layer: MotionLayer, fromShot: Bool, in scene: MotionScene, canvas: CGSize) -> Layer {
        let context = MoveContext(sceneDuration: scene.duration, canvas: canvas, layer: layer)
        var summary = Layer(id: layer.id, kind: "group", fromShot: fromShot, moves: layer.moves.map { move($0, in: context) })
        switch layer.content {
        case .text(let text):
            summary.kind = "text"
            summary.text = text.text
        case .lifted(let lifted):
            summary.kind = "ui"
            summary.asset = lifted.asset
        case .image:
            summary.kind = "image"
        case .shape:
            summary.kind = "shape"
        case .group(let children):
            summary.layers = children.map { self.layer($0, fromShot: fromShot, in: scene, canvas: canvas) }
        }
        return summary
    }

    private static func move(_ move: MotionMove, in context: MoveContext) -> Move {
        let timing = MoveExpansion.timing(of: move, in: context)
        return Move(move: move, starts: timing.start, ends: timing.start + timing.duration)
    }

    private enum CodingKeys: String, CodingKey {
        case frameRate = "frame_rate"
        case bundle, duration, pacing, assets, scenes, findings
    }
}
