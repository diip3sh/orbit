//
//  AreaSelectionView+DrawingRelease.swift
//  BetterCapture
//
//  Created by Diip3sh on 30.09.26.
//

import CoreGraphics

extension AreaSelectionView {

    /// Minimum selection size in points
    nonisolated static let minimumSize: CGFloat = 24

    /// Whether a selection is big enough to confirm
    nonisolated static func isValidSelection(_ rect: CGRect) -> Bool {
        rect.width >= minimumSize && rect.height >= minimumSize
    }

    /// What releasing the mouse after drawing does
    nonisolated enum DrawingRelease: Equatable {
        case confirm, adjust, cancel, reset
    }

    /// A big enough drag is confirmed at once or left to adjust. Anything smaller ends a selection
    /// that confirms on release, as a click does in the system screenshot, and otherwise starts over.
    nonisolated static func drawingRelease(of rect: CGRect, confirmsOnRelease: Bool) -> DrawingRelease {
        switch (isValidSelection(rect), confirmsOnRelease) {
        case (true, true): .confirm
        case (true, false): .adjust
        case (false, true): .cancel
        case (false, false): .reset
        }
    }
}
