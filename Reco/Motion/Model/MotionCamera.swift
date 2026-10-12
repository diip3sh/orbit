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

    /// Degrees the scene is turned about where the camera looks, as a layer's rotation is (x leans the top away, y turns the
    /// right edge away, z turns clockwise): the product seen from an angle, as launch films show UI on a plane lying back
    /// (spec 0020). `nil` looks straight at it.
    var angle: SIMD3<Double>?

    var moves: [MotionMove] = []
    var keyframes: [MotionProperty: [Keyframe]] = [:]

    /// The focal length as a share of the canvas's height: a layer at z 0 is this far from the
    /// camera at rest. 1.6 H drew Linear Agent's tilted planes with their foreshortening in spike C.
    static let focalLength = 1.6

    /// The depth of field a camera at an angle has unless it's keyed: blur in canvas pixels per 100 px of depth. Linear Agent's
    /// plane, lying back 30–40°, was sharp along a band through what it looked at and soft towards its far edge. At 3,
    /// Cardboard's third film blurred its transcript's title and its prompt's chips past reading.
    static let angledAperture = 2.0

    func base(_ property: MotionProperty, canvas: CGSize) -> Double {
        switch property {
        case .positionX: position?.x ?? canvas.width / 2
        case .positionY: position?.y ?? canvas.height / 2
        case .positionZ: position?.z ?? 0
        case .scale: 1
        case .rotationX: angle?.x ?? 0
        case .rotationY: angle?.y ?? 0
        case .rotationZ: angle?.z ?? 0
        case .aperture: (angle ?? .zero) == .zero ? 0 : Self.angledAperture
        default: 0
        }
    }
}

// MARK: - Codable

nonisolated extension MotionCamera: Codable {

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decodeIfPresent(SIMD3<Double>.self, forKey: .position)
        angle = try container.decodeIfPresent(SIMD3<Double>.self, forKey: .angle)
        moves = try container.decodeIfPresent([MotionMove].self, forKey: .moves) ?? []
        keyframes = try container.decodeIfPresent([MotionProperty: [Keyframe]].self, forKey: .keyframes) ?? [:]
    }
}
