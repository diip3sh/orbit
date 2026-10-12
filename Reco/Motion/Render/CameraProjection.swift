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

    /// The lens's zoom: 2 shows everything twice as large without changing its perspective.
    var zoom = 1.0

    /// How the scene is turned about the point at z 0 the camera looks at (``MotionCamera/angle``); `nil` looks straight.
    private let turn: simd_double4x4?

    /// - Parameter angle: Degrees about x, y and z, as a layer's rotation.
    init(lookAt: CGPoint, dolly: Double, canvas: CGSize, zoom: Double = 1, angle: SIMD3<Double> = .zero) {
        self.lookAt = lookAt
        self.dolly = dolly
        self.canvas = canvas
        self.zoom = zoom
        let pivot = SIMD3<Double>(Double(lookAt.x), Double(lookAt.y), 0)
        turn = angle == .zero ? nil : Transform3D(position: pivot, anchor: .zero, rotation: angle).matrix(size: .zero)
            * Transform3D(position: -pivot, anchor: .zero).matrix(size: .zero)
    }

    var focalLength: Double {
        MotionCamera.focalLength * canvas.height
    }

    /// How far to move in for a layer at z 0 to show `zoom` times larger.
    static func dolly(forZoom zoom: Double, canvas: CGSize) -> Double {
        MotionCamera.focalLength * canvas.height * (1 - 1 / zoom)
    }

    /// How many times larger than from rest a point at z 0 shows.
    var magnification: Double {
        focalLength * zoom / (focalLength - dolly)
    }

    /// Points closer than this to the camera, or behind it, aren't drawn: their planes would flip.
    var nearDepth: Double {
        focalLength * 0.05
    }

    /// How far a scene point is from the camera before it turns: what orders layers, farthest first. Turned, the far side of a
    /// card lying back is farther than its middle, and the card was drawn over what's on it.
    func order(of point: SIMD3<Double>) -> Double {
        point.z + focalLength - dolly
    }

    /// The canvas point (top-left origin) a scene point lands on, and how far in front of the camera
    /// it is; `nil` closer than ``nearDepth``.
    func project(_ point: SIMD3<Double>) -> (point: CGPoint, depth: Double)? {
        let point = turn.map { turn in
            let turned = turn * SIMD4(point, 1)
            return SIMD3(turned.x, turned.y, turned.z)
        } ?? point
        let depth = point.z + focalLength - dolly
        guard depth >= nearDepth else { return nil }
        let factor = focalLength * zoom / depth
        return (CGPoint(x: canvas.width / 2 + (point.x - lookAt.x) * factor, y: canvas.height / 2 + (point.y - lookAt.y) * factor), depth)
    }
}
