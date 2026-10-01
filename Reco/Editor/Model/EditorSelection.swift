//
//  EditorSelection.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

/// What's selected on the timeline, which ⌫ removes.
nonisolated enum EditorSelection: Equatable, Sendable {

    /// A kept part between splits and cuts, in source seconds.
    case segment(Range<Double>)

    case zoom(ZoomSegment.ID)
}
