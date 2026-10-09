//
//  MotionDocument.swift
//  Reco
//

import Foundation

/// A motion video: `document.json` in a `<name>.motion` bundle, with its images and lifted UI in
/// `assets/`.
nonisolated struct MotionDocument: Equatable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var canvas = MotionCanvas()
    var style = StyleTokens()
    var scenes: [MotionScene] = []

    /// UI to lift from web pages, shown by `ui` layers.
    var assets: [MotionAsset] = []

    /// The score and effects made for it.
    var sound = MotionSound()

    /// The video's length in seconds: every scene, end to end.
    var duration: Double {
        scenes.reduce(0) { $0 + $1.duration }
    }

    /// Throws the first problem that would make the document draw wrong or not at all.
    func validate() throws(MotionDocumentError) {
        guard canvas.size.width >= 16, canvas.size.height >= 16 else { throw .invalidCanvas }
        guard (1...120).contains(canvas.frameRate), (0...1).contains(canvas.fieldStrength) else { throw .invalidCanvas }
        guard MotionSound.levels.contains(sound.scoreLevel), MotionSound.levels.contains(sound.effectsLevel) else { throw .invalidSound }
        try validateStyle()
        guard !scenes.isEmpty else { throw .noScenes }
        let assetIDs = try validatedAssetIDs()
        var sceneIDs = Set<String>()
        for (index, scene) in scenes.enumerated() {
            guard sceneIDs.insert(scene.id).inserted else { throw .duplicateID(scene.id) }
            // At least a frame, so every scene shows
            guard scene.duration >= 1 / Double(canvas.frameRate) else { throw .invalidDuration(scene.id) }
            guard Set(scene.camera.keyframes.keys).isSubset(of: MotionProperty.camera) else { throw .invalidCameraProperty(scene.id) }
            if let reason = scene.shot?.problem(assets: assetIDs) {
                throw .invalidShot(scene.id, reason)
            }
            if let reason = scene.camera.moves.lazy.compactMap({ $0.problem(on: nil) }).first {
                throw .invalidMove(scene.id, reason)
            }
            var layerIDs = Set<String>()
            try validate(scene.layers, ids: &layerIDs, assets: assetIDs)
            try validateShotMoves(of: index)
        }
    }

    /// The style's gradient, if it has one, is 2 to 5 colours.
    private func validateStyle() throws(MotionDocumentError) {
        guard style.gradient.map({ (2...5).contains($0.count) }) ?? true else { throw .invalidGradient }
    }

    /// Each of a scene's ``MotionScene/shotMoves`` names its shot's camera or one of its layers,
    /// and suits it.
    private func validateShotMoves(of index: Int) throws(MotionDocumentError) {
        let scene = scenes[index]
        guard !scene.shotMoves.isEmpty else { return }
        let layers = DocumentExpansion.laidOut(self, scene: index, sizes: [:]).layers
        for (id, moves) in scene.shotMoves {
            let content: LayerContent?
            if id == MotionScene.cameraID, scene.shot != nil {
                content = nil
            } else if let layer = layers.first(where: { $0.id == id }) {
                content = layer.content
            } else {
                throw .invalidMove(id, "scene \"\(scene.id)\"'s shot has no layer \"\(id)\".")
            }
            if let reason = moves.lazy.compactMap({ $0.problem(on: content) }).first {
                throw .invalidMove(id, reason)
            }
        }
    }

    /// The assets' ids, once each is known to be lifted from somewhere.
    private func validatedAssetIDs() throws(MotionDocumentError) -> Set<String> {
        var ids = Set<String>()
        for asset in assets {
            guard ids.insert(asset.id).inserted else { throw .duplicateID(asset.id) }
            guard ["http", "https"].contains(asset.url.scheme?.lowercased()), asset.viewport.width >= 16, asset.viewport.height >= 16 else {
                throw .invalidAsset(asset.id)
            }
            do {
                _ = try asset.takePlan()
            } catch {
                throw .invalidSteps(asset.id, error.localizedDescription)
            }
            if let reason = asset.stillProblem {
                throw .invalidSteps(asset.id, reason)
            }
        }
        return ids
    }

    private func validate(_ layers: [MotionLayer], ids: inout Set<String>, assets: Set<String>) throws(MotionDocumentError) {
        for layer in layers {
            guard ids.insert(layer.id).inserted else { throw .duplicateID(layer.id) }
            let scales = [layer.transform.scale] + (layer.keyframes[.scale] ?? []).map(\.value)
            guard scales.allSatisfy({ $0 > 0 }) else { throw .invalidScale(layer.id) }
            guard Set(layer.keyframes.keys).isSubset(of: MotionProperty.layer) else { throw .invalidCameraProperty(layer.id) }
            if let reason = layer.moves.lazy.compactMap({ $0.problem(on: layer.content) }).first {
                throw .invalidMove(layer.id, reason)
            }
            if case .group(let children) = layer.content {
                try validate(children, ids: &ids, assets: assets)
            } else if let problem = Self.problem(with: layer, assets: assets) {
                throw problem
            }
        }
    }

    /// What's wrong with a layer's own content, if anything.
    private static func problem(with layer: MotionLayer, assets: Set<String>) -> MotionDocumentError? {
        switch layer.content {
        case .image(let image):
            image.size.width > 0 && image.size.height > 0 ? nil : .invalidSize(layer.id)
        case .lifted(let lifted):
            if !assets.contains(lifted.asset) {
                .unknownAsset(layer.id)
            } else {
                lifted.width.map { $0 > 0 } ?? true ? nil : .invalidSize(layer.id)
            }
        case .shape(let shape):
            shape.size.width > 0 && shape.size.height > 0 ? nil : .invalidSize(layer.id)
        case .text, .group:
            nil
        }
    }
}

// MARK: - Codable

nonisolated extension MotionDocument: Codable {

    /// Decodes a file, rejecting any version but ``currentVersion`` with ``UnsupportedVersionError``.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw UnsupportedVersionError(version: version)
        }
        canvas = try container.decodeIfPresent(MotionCanvas.self, forKey: .canvas) ?? MotionCanvas()
        style = try container.decodeIfPresent(StyleTokens.self, forKey: .style) ?? StyleTokens()
        scenes = try container.decode([MotionScene].self, forKey: .scenes)
        assets = try container.decodeIfPresent([MotionAsset].self, forKey: .assets) ?? []
        sound = try container.decodeIfPresent(MotionSound.self, forKey: .sound) ?? MotionSound()
    }
}
