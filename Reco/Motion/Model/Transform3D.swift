//
//  Transform3D.swift
//  Reco
//

import CoreGraphics
import simd

/// Where a layer's plane sits in the scene: its anchor at `position`, scaled and rotated about it.
///
/// Canvas pixels with a top-left origin, y down and z away from the camera; a layer at z 0, unscaled
/// and unrotated, shows at its size with the camera at rest.
nonisolated struct Transform3D: Equatable, Sendable {
    var position = SIMD3<Double>.zero

    /// The point the layer turns and scales about, as fractions of its size from its top-left corner.
    var anchor = CGPoint(x: 0.5, y: 0.5)

    var scale = 1.0

    /// Degrees about x, y and z; see ``MotionProperty/rotationX``.
    var rotation = SIMD3<Double>.zero

    /// Maps a point in a layer of `size` (its pixels from its top-left corner) to the scene: x
    /// rotation first, then y, then z, as CSS's `rotateX() rotateY() rotateZ()` composes.
    func matrix(size: CGSize) -> simd_double4x4 {
        let radians = rotation * .pi / 180
        // Negated about x and y: with z away from the camera, CSS's directions turn the other way
        let (cosX, sinX) = (cos(-radians.x), sin(-radians.x))
        let (cosY, sinY) = (cos(-radians.y), sin(-radians.y))
        let (cosZ, sinZ) = (cos(radians.z), sin(radians.z))
        let rotateX = simd_double4x4(rows: [[1, 0, 0, 0], [0, cosX, -sinX, 0], [0, sinX, cosX, 0], [0, 0, 0, 1]])
        let rotateY = simd_double4x4(rows: [[cosY, 0, sinY, 0], [0, 1, 0, 0], [-sinY, 0, cosY, 0], [0, 0, 0, 1]])
        let rotateZ = simd_double4x4(rows: [[cosZ, -sinZ, 0, 0], [sinZ, cosZ, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]])
        let anchored = Self.translation([-anchor.x * size.width, -anchor.y * size.height, 0])
        let scaled = simd_double4x4(diagonal: [scale, scale, scale, 1])
        return Self.translation(position) * rotateZ * rotateY * rotateX * scaled * anchored
    }

    private static func translation(_ offset: SIMD3<Double>) -> simd_double4x4 {
        simd_double4x4(rows: [[1, 0, 0, offset.x], [0, 1, 0, offset.y], [0, 0, 1, offset.z], [0, 0, 0, 1]])
    }
}

// MARK: - Codable

nonisolated extension Transform3D: Codable {

    /// Every field may be left out for its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decodeIfPresent(SIMD3<Double>.self, forKey: .position) ?? .zero
        anchor = try container.decodeIfPresent(CGPoint.self, forKey: .anchor) ?? CGPoint(x: 0.5, y: 0.5)
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        rotation = try container.decodeIfPresent(SIMD3<Double>.self, forKey: .rotation) ?? .zero
    }
}
