//
//  CameraProjection.swift
//  Reco
//

import CoreGraphics
import simd

/// What the camera sees at one moment: maps points in the scene to the canvas.
///
/// The camera sits ``MotionCamera/focalLength`` canvas heights in front of z 0, less how far it
/// moved in, looking straight at `lookAt`; a point at z 0 shows 1:1 from rest.
nonisolated struct CameraProjection: Equatable, Sendable {
    let lookAt: CGPoint

    /// How far the camera moved towards the layers, in canvas pixels.
    let dolly: Double

    let canvas: CGSize

    var focalLength: Double {
        MotionCamera.focalLength * canvas.height
    }

    /// Points closer than this to the camera, or behind it, aren't drawn: their planes would flip.
    var nearDepth: Double {
        focalLength * 0.05
    }

    /// The canvas point (top-left origin) a scene point lands on, and how far in front of the camera
    /// it is; `nil` closer than ``nearDepth``.
    func project(_ point: SIMD3<Double>) -> (point: CGPoint, depth: Double)? {
        let depth = point.z + focalLength - dolly
        guard depth >= nearDepth else { return nil }
        let factor = focalLength / depth
        return (CGPoint(x: canvas.width / 2 + (point.x - lookAt.x) * factor, y: canvas.height / 2 + (point.y - lookAt.y) * factor), depth)
    }
}
