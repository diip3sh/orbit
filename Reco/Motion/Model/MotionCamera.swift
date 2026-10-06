//
//  MotionCamera.swift
//  Reco
//

import CoreGraphics
import simd

/// The one camera that looks at a scene: at a point on the canvas from in front of it, moved by the
/// grammar's camera moves and keyframes.
nonisolated struct MotionCamera: Equatable, Sendable {

    /// Where the camera looks, in canvas pixels, and how far it has moved in (z, towards the
    /// layers); `nil` for the canvas's centre from rest, where a layer at z 0 shows 1:1.
    var position: SIMD3<Double>?

    var moves: [MotionMove] = []
    var keyframes: [MotionProperty: [Keyframe]] = [:]

    /// The focal length as a share of the canvas's height: a layer at z 0 is this far from the
    /// camera at rest. 1.6 H drew Linear Agent's tilted planes with their foreshortening in spike C.
    static let focalLength = 1.6

    func base(_ property: MotionProperty, canvas: CGSize) -> Double {
        switch property {
        case .positionX: position?.x ?? canvas.width / 2
        case .positionY: position?.y ?? canvas.height / 2
        case .positionZ: position?.z ?? 0
        case .scale: 1
        default: 0
        }
    }
}

// MARK: - Codable

nonisolated extension MotionCamera: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decodeIfPresent(SIMD3<Double>.self, forKey: .position)
        moves = try container.decodeIfPresent([MotionMove].self, forKey: .moves) ?? []
        keyframes = try container.decodeIfPresent([MotionProperty: [Keyframe]].self, forKey: .keyframes) ?? [:]
    }
}
