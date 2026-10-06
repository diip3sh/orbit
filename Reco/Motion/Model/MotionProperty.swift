//
//  MotionProperty.swift
//  Reco
//

import Foundation

/// What a keyframe track or a move animates: a layer's ``layer`` properties, a camera's ``camera``
/// ones.
nonisolated enum MotionProperty: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {

    /// Position in canvas pixels; z is depth, away from the camera. Coded `x`, `y` and `z`.
    case positionX = "x", positionY = "y", positionZ = "z"

    /// A layer's size; for a camera, its zoom (the lens, so depth keeps its perspective).
    case scale

    /// Degrees, as in CSS: x leans the top away, y turns the right edge away, z turns clockwise.
    case rotationX, rotationY, rotationZ

    case opacity

    /// Gaussian blur radius in canvas pixels; for a camera, of the whole frame.
    case blur

    /// How strong a layer's shadow is, 1 as the document gives it; it is cast farther as it grows.
    case shadow

    /// How far a layer outside its focused region (``MotionMove/region``) is darkened, 0 to 1.
    case dim

    /// The camera's depth of field: the z that is sharp, and the blur in canvas pixels for each
    /// 100 pixels of depth away from it (0, the default, keeps everything sharp).
    case focus, aperture

    static let layer: Set<MotionProperty> = [.positionX, .positionY, .positionZ, .scale, .rotationX, .rotationY, .rotationZ, .opacity, .blur, .shadow, .dim]
    static let camera: Set<MotionProperty> = [.positionX, .positionY, .positionZ, .scale, .blur, .focus, .aperture]

    /// Whether moves multiply its value rather than add to it.
    var isFactor: Bool {
        self == .scale || self == .opacity || self == .shadow
    }
}
