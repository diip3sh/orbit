//
//  MotionProperty.swift
//  Reco
//

import Foundation

/// What a keyframe track animates. A layer has all of them; a camera only its position.
nonisolated enum MotionProperty: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {

    /// Position in canvas pixels; z is depth, away from the camera. Coded `x`, `y` and `z`.
    case positionX = "x", positionY = "y", positionZ = "z"

    case scale

    /// Degrees, as in CSS: x leans the top away, y turns the right edge away, z turns clockwise.
    case rotationX, rotationY, rotationZ

    case opacity

    /// Gaussian blur radius in canvas pixels.
    case blur

    static let camera: Set<MotionProperty> = [.positionX, .positionY, .positionZ]
}
