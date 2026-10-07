//
//  MotionScene.swift
//  Reco
//

import Foundation

/// A shot: layers and a camera for `duration` seconds. Scenes play one after another, each
/// beginning with its seam.
nonisolated struct MotionScene: Equatable, Sendable, Identifiable {
    var id: String
    var duration: Double

    /// A shot from the grammar, laid out under ``layers``.
    var shot: MotionShot?

    /// How it begins after the scene before.
    var seam = MotionSeam.cut

    /// What it's drawn over, when not the canvas's field: `halo` behind an end card.
    var field: MotionField?

    /// Drawn farthest first; layers at the same depth in this order.
    var layers: [MotionLayer] = []

    /// Moves replacing those the shot gives its layers, by layer id, and its camera's under
    /// ``cameraID``. The layer stays where the shot lays it out, which a copy in ``layers`` wouldn't.
    var shotMoves: [String: [MotionMove]] = [:]

    var camera = MotionCamera()

    /// The key of ``shotMoves`` naming the shot's camera.
    static let cameraID = "camera"
}

// MARK: - Codable

nonisolated extension MotionScene: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        duration = try container.decode(Double.self, forKey: .duration)
        shot = try container.decodeIfPresent(MotionShot.self, forKey: .shot)
        seam = try container.decodeIfPresent(MotionSeam.self, forKey: .seam) ?? .cut
        field = try container.decodeIfPresent(MotionField.self, forKey: .field)
        layers = try container.decodeIfPresent([MotionLayer].self, forKey: .layers) ?? []
        shotMoves = try container.decodeIfPresent([String: [MotionMove]].self, forKey: .shotMoves) ?? [:]
        camera = try container.decodeIfPresent(MotionCamera.self, forKey: .camera) ?? MotionCamera()
    }
}
