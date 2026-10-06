//
//  MotionLayer.swift
//  Reco
//

import Foundation

/// A plane in a scene: its content, where it sits (`transform`, `opacity`, `blur`), the grammar's
/// moves on it, and keyframes. A property with keyframes takes their value, set by hand over
/// whatever the moves do; one without is its base changed by its moves.
nonisolated struct MotionLayer: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var content: LayerContent
    var transform = Transform3D()
    var opacity = 1.0
    var blur = 0.0
    var shadow: LayerShadow?
    var moves: [MotionMove] = []
    var keyframes: [MotionProperty: [Keyframe]] = [:]

    init(
        id: String, name: String? = nil, content: LayerContent, transform: Transform3D = Transform3D(), moves: [MotionMove] = [],
        keyframes: [MotionProperty: [Keyframe]] = [:]
    ) {
        self.id = id
        self.name = name ?? id
        self.content = content
        self.transform = transform
        self.moves = moves
        self.keyframes = keyframes
    }

    /// The base value of `property`, before moves and keyframes.
    func base(_ property: MotionProperty) -> Double {
        let values: [MotionProperty: Double] = [
            .positionX: transform.position.x, .positionY: transform.position.y, .positionZ: transform.position.z, .scale: transform.scale,
            .rotationX: transform.rotation.x, .rotationY: transform.rotation.y, .rotationZ: transform.rotation.z,
            .opacity: opacity, .blur: blur, .shadow: 1
        ]
        return values[property] ?? 0
    }
}

// MARK: - Codable

nonisolated extension MotionLayer: Codable {

    /// Only `id` and `content` are required; `name` defaults to the id.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        content = try container.decode(LayerContent.self, forKey: .content)
        transform = try container.decodeIfPresent(Transform3D.self, forKey: .transform) ?? Transform3D()
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        blur = try container.decodeIfPresent(Double.self, forKey: .blur) ?? 0
        shadow = try container.decodeIfPresent(LayerShadow.self, forKey: .shadow)
        moves = try container.decodeIfPresent([MotionMove].self, forKey: .moves) ?? []
        keyframes = try container.decodeIfPresent([MotionProperty: [Keyframe]].self, forKey: .keyframes) ?? [:]
    }
}
