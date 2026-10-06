//
//  MotionLayer.swift
//  Reco
//

import Foundation

/// A plane in a scene: its content, where it sits (`transform`, `opacity`, `blur`), and keyframes
/// that animate those properties over the scene. A property with keyframes takes their value; one
/// without keeps its base.
nonisolated struct MotionLayer: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var content: LayerContent
    var transform = Transform3D()
    var opacity = 1.0
    var blur = 0.0
    var shadow: LayerShadow?
    var keyframes: [MotionProperty: [Keyframe]] = [:]

    init(id: String, name: String? = nil, content: LayerContent, transform: Transform3D = Transform3D(), keyframes: [MotionProperty: [Keyframe]] = [:]) {
        self.id = id
        self.name = name ?? id
        self.content = content
        self.transform = transform
        self.keyframes = keyframes
    }

    /// The base value of `property`, before keyframes.
    func base(_ property: MotionProperty) -> Double {
        switch property {
        case .positionX: transform.position.x
        case .positionY: transform.position.y
        case .positionZ: transform.position.z
        case .scale: transform.scale
        case .rotationX: transform.rotation.x
        case .rotationY: transform.rotation.y
        case .rotationZ: transform.rotation.z
        case .opacity: opacity
        case .blur: blur
        }
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
        keyframes = try container.decodeIfPresent([MotionProperty: [Keyframe]].self, forKey: .keyframes) ?? [:]
    }
}
