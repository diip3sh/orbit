//
//  MotionScene.swift
//  Reco
//

import Foundation

/// A shot: layers and a camera for `duration` seconds. Scenes play one after another, cut to cut.
nonisolated struct MotionScene: Equatable, Sendable, Identifiable {
    var id: String
    var duration: Double

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
        layers = try container.decodeIfPresent([MotionLayer].self, forKey: .layers) ?? []
        camera = try container.decodeIfPresent(MotionCamera.self, forKey: .camera) ?? MotionCamera()
    }
}
