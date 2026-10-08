//
//  ZoomMotion.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// How quickly the camera moves into, out of and between zooms.
nonisolated enum ZoomMotion: String, Codable, CaseIterable, Sendable {
    case mellow
    case smooth
    case fast

    /// The camera spring's natural frequency, in radians per second. A critically damped spring is 96%
    /// of the way after 5 / `frequency` seconds: 0.83 s, 0.5 s and 0.31 s. Smooth is the 10 rad/s the
    /// camera always used; it stops within 0.04 px of its target at 4K about 1.4 s after a 2× zoom
    /// starts or ends.
    var frequency: Double {
        switch self {
        case .mellow: 6
        case .smooth: 10
        case .fast: 16
        }
    }
}
