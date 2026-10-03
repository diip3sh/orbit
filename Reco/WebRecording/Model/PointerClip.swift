//
//  PointerClip.swift
//  Reco
//

import Foundation

/// A clip on the Cursor lane: the cursor arrives at its target when the clip starts and stays there
/// until it ends, clicking at the start of a click clip and then typing its text, if it has any.
nonisolated struct PointerClip: Codable, Equatable, Sendable, TimelineClip {
    var id = UUID()
    var range: Range<Double>
    var action: Action
    var target: WebTarget

    /// What a click clip types into its target once it has clicked it. A new line is Enter.
    var text: String?

    /// A selector for the element the video zooms on while the clip runs (``WebTakeZooms``), or
    /// `nil` to leave the zooms to the editor.
    var show: String?

    nonisolated enum Action: String, Codable, CaseIterable, Sendable {
        case hover
        case click
    }

    static let minimumDuration = 0.2

    /// A clip added by hand lasts this long, if there's room.
    static let defaultDuration = 1.0

    /// How long a click holds the button down, or the whole clip when it's shorter.
    static let pressDuration = 0.1

    /// How long after the click the first key is typed, and how long each key takes: 12 a second,
    /// fast typing that can still be followed.
    static let typingDelay = 0.3
    static let keyInterval = 0.08

    /// How long the typed text is left to read when a clip is timed for it.
    static let readingTime = 0.8

    /// How long a clip that types `text` lasts when timed for it.
    static func typingDuration(of text: String) -> Double {
        typingDelay + Double(text.count) * keyInterval + readingTime
    }

    /// When each character of ``text`` is typed: ``keyInterval`` apart from ``typingDelay`` after
    /// the click, or closer when the clip is too short for that.
    var keystrokes: [(time: Double, character: Character)] {
        guard action == .click, let text, !text.isEmpty else { return [] }
        let start = range.lowerBound + min(Self.typingDelay, (range.upperBound - range.lowerBound) / 2)
        let interval = min(Self.keyInterval, (range.upperBound - start) / Double(text.count))
        return text.enumerated().map { (start + Double($0.offset) * interval, $0.element) }
    }
}
