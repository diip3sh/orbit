//
//  MotionEdit.swift
//  Reco
//

import CoreGraphics
import Foundation

/// One change to a motion document, as `edit_motion` names it (spec 0011, *Agent*): coded
/// `{"op": "set_moves", "id": "hero", "target": "headline", "moves": [...]}`. Only the fields its
/// operation reads are set.
nonisolated struct MotionEdit: Codable, Equatable, Sendable {

    nonisolated enum Operation: String, Codable, CaseIterable, Sendable {
        /// `canvas`: the fields to change.
        case setCanvas = "set_canvas"
        /// `style`: the fields to change.
        case setStyle = "set_style"
        /// `asset`: added, or replacing the one with its id.
        case setAsset = "set_asset"
        /// `scene`, at `index` or last.
        case addScene = "add_scene"
        /// Scene `id`'s `duration`, `seam`, `shot` or `field`.
        case setScene = "set_scene"
        /// `layer` in scene `id`: added, or replacing its own layer with that id; one with a shot
        /// layer's id replaces that layer whole.
        case setLayer = "set_layer"
        /// The `moves` of layer `target` in scene `id`, or of its camera when `target` is `camera`.
        case setMoves = "set_moves"
        /// Scene `id` to `index`.
        case moveScene = "move_scene"
        /// Scene `id`, its layer `target`, or the asset `id`. A shot's layer goes back to the shot's.
        case remove
    }

    var operation: Operation
    var id: String?
    var target: String?
    var index: Int?
    var canvas: CanvasChange?
    var style: StyleChange?
    var asset: MotionAsset?
    var scene: MotionScene?
    var layer: MotionLayer?
    var duration: Double?
    var seam: MotionSeam?
    var shot: MotionShot?
    var field: MotionField?
    var moves: [MotionMove]?

    private enum CodingKeys: String, CodingKey {
        case operation = "op"
        case id, target, index, canvas, style, asset, scene, layer, duration, seam, shot, field, moves
    }

    init(_ operation: Operation, id: String? = nil, target: String? = nil) {
        self.operation = operation
        self.id = id
        self.target = target
    }

    nonisolated struct CanvasChange: Codable, Equatable, Sendable {
        var size: CGSize?
        var frameRate: Int?
        var background: RGBAColor?
        var field: MotionField?
        var pacing: MotionCanvas.Pacing?
    }

    nonisolated struct StyleChange: Codable, Equatable, Sendable {
        var text: RGBAColor?
        var dim: RGBAColor?
        var accent: RGBAColor?
        var face: TextContent.Face?
        var alignment: TextContent.Alignment?
    }

    /// The undo step's name, as the Edit menu shows it.
    var actionName: String {
        switch operation {
        case .setCanvas: "Canvas"
        case .setStyle: "Style"
        case .setAsset: "UI"
        case .addScene: "Add Scene"
        case .setScene: "Scene"
        case .setLayer: "Layer"
        case .setMoves: "Moves"
        case .moveScene: "Move Scene"
        case .remove: "Delete"
        }
    }
}

// MARK: - Applying

nonisolated extension MotionEdit {

    /// Applies the change to `document`, or throws why it can't be, naming what exists instead.
    /// The result isn't validated: a batch is, once whole.
    func apply(to document: inout MotionDocument) throws(MotionEditError) {
        switch operation {
        case .setCanvas:
            let change = try required(canvas, "canvas")
            document.canvas.size = change.size ?? document.canvas.size
            document.canvas.frameRate = change.frameRate ?? document.canvas.frameRate
            document.canvas.background = change.background ?? document.canvas.background
            document.canvas.field = change.field ?? document.canvas.field
            document.canvas.pacing = change.pacing ?? document.canvas.pacing
        case .setStyle:
            let change = try required(style, "style")
            document.style.text = change.text ?? document.style.text
            document.style.dim = change.dim ?? document.style.dim
            document.style.accent = change.accent ?? document.style.accent
            document.style.face = change.face ?? document.style.face
            document.style.alignment = change.alignment ?? document.style.alignment
        case .setAsset:
            let asset = try required(asset, "asset")
            document.assets.removeAll { $0.id == asset.id }
            document.assets.append(asset)
        case .addScene:
            let scene = try required(scene, "scene")
            document.scenes.insert(scene, at: min(max(index ?? document.scenes.count, 0), document.scenes.count))
        case .setScene:
            try setScene(in: &document)
        case .setLayer:
            try setLayer(in: &document)
        case .setMoves:
            try setMoves(in: &document)
        case .moveScene:
            let from = try sceneIndex(in: document)
            let destination = try required(index, "index")
            guard document.scenes.indices.contains(destination) else { throw .init("index must be 0 to \(document.scenes.count - 1).") }
            document.scenes.insert(document.scenes.remove(at: from), at: destination)
        case .remove:
            try remove(from: &document)
        }
    }

    private func setLayer(in document: inout MotionDocument) throws(MotionEditError) {
        let index = try sceneIndex(in: document)
        let layer = try required(layer, "layer")
        if !Self.update(&document.scenes[index].layers, id: layer.id, with: { $0 = layer }) {
            document.scenes[index].layers.append(layer)
        }
    }

    private func setScene(in document: inout MotionDocument) throws(MotionEditError) {
        let index = try sceneIndex(in: document)
        guard duration != nil || seam != nil || shot != nil || field != nil else { throw .init("set_scene needs duration, seam, shot or field.") }
        document.scenes[index].duration = duration ?? document.scenes[index].duration
        document.scenes[index].seam = seam ?? document.scenes[index].seam
        document.scenes[index].shot = shot ?? document.scenes[index].shot
        document.scenes[index].field = field ?? document.scenes[index].field
    }

    private func setMoves(in document: inout MotionDocument) throws(MotionEditError) {
        let index = try sceneIndex(in: document)
        let target = try required(target, "target")
        let moves = try required(moves, "moves")
        var scene = document.scenes[index]
        if target == MotionScene.cameraID {
            if scene.shot == nil {
                scene.camera.moves = moves
            } else {
                scene.shotMoves[target] = moves
                scene.camera.moves = []
            }
        } else if !Self.update(&scene.layers, id: target, with: { $0.moves = moves }) {
            guard Self.shotLayerIDs(of: index, in: document).contains(target) else {
                throw .init("scene \"\(scene.id)\" has no layer \"\(target)\"; it has \(Self.layerIDs(of: index, in: document)).")
            }
            scene.shotMoves[target] = moves
        }
        document.scenes[index] = scene
    }

    private func remove(from document: inout MotionDocument) throws(MotionEditError) {
        let id = try required(id, "id")
        if let target {
            let index = try sceneIndex(in: document)
            if Self.remove(target, from: &document.scenes[index].layers) {
                return
            }
            guard document.scenes[index].shotMoves.removeValue(forKey: target) != nil else {
                throw .init("scene \"\(id)\" has no layer \"\(target)\" of its own; a shot's layers change with the shot.")
            }
        } else if let index = document.scenes.firstIndex(where: { $0.id == id }) {
            document.scenes.remove(at: index)
        } else if let index = document.assets.firstIndex(where: { $0.id == id }) {
            document.assets.remove(at: index)
        } else {
            throw .init("no scene or asset \"\(id)\".")
        }
    }

    // MARK: Lookup

    private func required<Value>(_ value: Value?, _ field: String) throws(MotionEditError) -> Value {
        guard let value else { throw .init("\(operation.rawValue) needs \(field).") }
        return value
    }

    private func sceneIndex(in document: MotionDocument) throws(MotionEditError) -> Int {
        let id = try required(id, "id")
        guard let index = document.scenes.firstIndex(where: { $0.id == id }) else {
            throw .init("no scene \"\(id)\"; the scenes are \(document.scenes.map(\.id).joined(separator: ", ")).")
        }
        return index
    }

    private static func shotLayerIDs(of index: Int, in document: MotionDocument) -> Set<String> {
        Set(DocumentExpansion.laidOut(document, scene: index, sizes: [:]).layers.map(\.id))
    }

    private static func layerIDs(of index: Int, in document: MotionDocument) -> String {
        let ids = DocumentExpansion.laidOut(document, scene: index, sizes: [:]).layers.map(\.id)
        return ids.isEmpty ? "no layers" : (["camera"] + ids).joined(separator: ", ")
    }

    /// Changes the layer `id` among `layers` or inside their groups; `false` when there's none.
    private static func update(_ layers: inout [MotionLayer], id: String, with change: (inout MotionLayer) -> Void) -> Bool {
        for index in layers.indices {
            if layers[index].id == id {
                change(&layers[index])
                return true
            }
            if case .group(var children) = layers[index].content, update(&children, id: id, with: change) {
                layers[index].content = .group(children)
                return true
            }
        }
        return false
    }

    private static func remove(_ id: String, from layers: inout [MotionLayer]) -> Bool {
        if let index = layers.firstIndex(where: { $0.id == id }) {
            layers.remove(at: index)
            return true
        }
        for index in layers.indices {
            if case .group(var children) = layers[index].content, remove(id, from: &children) {
                layers[index].content = .group(children)
                return true
            }
        }
        return false
    }
}

/// Why an edit can't be applied.
nonisolated struct MotionEditError: LocalizedError, Equatable {
    let reason: String

    init(_ reason: String) {
        self.reason = reason
    }

    var errorDescription: String? {
        reason
    }
}
