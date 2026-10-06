//
//  MotionSeam.swift
//  Reco
//

import Foundation

/// How a scene begins after the one before (``SeamExpansion``). Reference films cut 68% of the time,
/// move through 25% and fade 5% (Remocn, 449 intervals).
nonisolated enum MotionSeam: String, Codable, CaseIterable, Sendable {
    case cut

    /// A cut that carries the camera's speed and direction into the next scene, then settles.
    case cutOnMotion

    /// The camera rushes in 0.2 s and lands from a pulled-back view in 0.5 s, blurred across the cut.
    case zoomThrough

    /// The frame blurs out and the next blurs in.
    case blurCut

    /// The next scene slides in and pushes this one out.
    case push

    /// A cross-fade: rare in the references.
    case fade
}
