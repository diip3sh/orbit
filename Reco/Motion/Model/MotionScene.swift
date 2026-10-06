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

    /// Drawn farthest first; layers at the same depth in this order.
    var layers: [MotionLayer] = []

    var camera = MotionCamera()
}

// MARK: - Codable

nonisolated extension MotionScene: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        duration = try container.decode(Double.self, forKey: .duration)
        shot = try container.decodeIfPresent(MotionShot.self, forKey: .shot)
        seam = try container.decodeIfPresent(MotionSeam.self, forKey: .seam) ?? .cut
        layers = try container.decodeIfPresent([MotionLayer].self, forKey: .layers) ?? []
        camera = try container.decodeIfPresent(MotionCamera.self, forKey: .camera) ?? MotionCamera()
    }
}
