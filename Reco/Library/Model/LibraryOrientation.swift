//
//  LibraryOrientation.swift
//  Reco
//

import Foundation

/// A picture's shape, for the Library's filter.
nonisolated enum LibraryOrientation: CaseIterable, Hashable, Sendable {
    case landscape
    case portrait
    case square

    /// Square within 5% either way, so a 1:1 canvas exported at an odd pixel size still counts.
    init(aspectRatio: Double) {
        if abs(aspectRatio - 1) <= 0.05 {
            self = .square
        } else {
            self = aspectRatio > 1 ? .landscape : .portrait
        }
    }
}
