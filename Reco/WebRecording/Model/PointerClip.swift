//
//  PointerClip.swift
//  Reco
//

import Foundation

/// A clip on the Cursor lane: the cursor arrives at its target when the clip starts and stays there
/// until it ends, clicking at the start of a click clip.
nonisolated struct PointerClip: Codable, Equatable, Sendable, TimelineClip {
    var id = UUID()
    var range: Range<Double>
    var action: Action
    var target: WebTarget

    nonisolated enum Action: String, Codable, CaseIterable, Sendable {
        case hover
        case click
    }

    static let minimumDuration = 0.2

    /// A clip added by hand lasts this long, if there's room.
    static let defaultDuration = 1.0

    /// How long a click holds the button down, or the whole clip when it's shorter.
    static let pressDuration = 0.1
}
