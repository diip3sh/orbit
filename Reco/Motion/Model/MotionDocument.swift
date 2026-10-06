//
//  MotionDocument.swift
//  Reco
//

import Foundation

/// A motion video: `document.json` in a `<name>.motion` bundle, with its images in `assets/`.
nonisolated struct MotionDocument: Equatable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var canvas = MotionCanvas()
    var scenes: [MotionScene] = []

    /// The video's length in seconds: every scene, end to end.
    var duration: Double {
        scenes.reduce(0) { $0 + $1.duration }
    }

    /// Throws the first problem that would make the document draw wrong or not at all.
    func validate() throws(MotionDocumentError) {
        guard canvas.size.width >= 16, canvas.size.height >= 16 else { throw .invalidCanvas }
        guard (1...120).contains(canvas.frameRate) else { throw .invalidCanvas }
        guard !scenes.isEmpty else { throw .noScenes }
        var sceneIDs = Set<String>()
        for scene in scenes {
            guard sceneIDs.insert(scene.id).inserted else { throw .duplicateID(scene.id) }
            // At least a frame, so every scene shows
            guard scene.duration >= 1 / Double(canvas.frameRate) else { throw .invalidDuration(scene.id) }
            guard Set(scene.camera.keyframes.keys).isSubset(of: MotionProperty.camera) else { throw .invalidCameraProperty(scene.id) }
            var layerIDs = Set<String>()
            try validate(scene.layers, ids: &layerIDs)
        }
    }

    private func validate(_ layers: [MotionLayer], ids: inout Set<String>) throws(MotionDocumentError) {
        for layer in layers {
            guard ids.insert(layer.id).inserted else { throw .duplicateID(layer.id) }
            let scales = [layer.transform.scale] + (layer.keyframes[.scale] ?? []).map(\.value)
            guard scales.allSatisfy({ $0 > 0 }) else { throw .invalidScale(layer.id) }
            switch layer.content {
            case .image(let image):
                guard image.size.width > 0, image.size.height > 0 else { throw .invalidSize(layer.id) }
            case .shape(let shape):
                guard shape.size.width > 0, shape.size.height > 0 else { throw .invalidSize(layer.id) }
            case .group(let children):
                try validate(children, ids: &ids)
            case .text:
                break
            }
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
        scenes = try container.decode([MotionScene].self, forKey: .scenes)
    }
}
