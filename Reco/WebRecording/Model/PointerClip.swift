//
//  PointerClip.swift
//  Reco
//

import Foundation

/// A clip on the Cursor lane: the cursor arrives at its target when the clip starts and stays there
/// until it ends, clicking at the start of a click clip. A type clip clicks its field, then types its
/// ``text`` into it letter by letter until the clip ends (spec 0009).
nonisolated struct PointerClip: Codable, Equatable, Sendable, TimelineClip {
    var id = UUID()
    var range: Range<Double>
    var action: Action
    var target: WebTarget

    /// How much the camera magnifies the target around this clip, e.g. 2; `nil` for no zoom
    /// (``WebCamera``). Scripts saved before zooms decode without it.
    var zoom: Double?

    /// What a type clip types into its target; `nil` for the other actions.
    var text: String?

    nonisolated enum Action: String, Codable, CaseIterable, Sendable {
        case hover
        case click
        case type

        /// Whether the clip presses on its target when it starts: a type clip clicks to focus its field.
        var presses: Bool {
            self != .hover
        }
    }

    static let minimumDuration = 0.2

    /// A clip added by hand lasts this long, if there's room.
    static let defaultDuration = 1.0

    /// How long a click holds the button down, or the whole clip when it's shorter.
    static let pressDuration = 0.1

    /// The time between typed letters when a clip's length comes from its text: 12.5 a second, a
    /// quick typist's pace that still reads on screen. A choice, not measured.
    static let typingInterval = 0.08

    /// Typing starts this long after the press that focuses the field, and ends this long before the
    /// clip does, so the whole text shows before the cursor moves on.
    static let typingMargin = 0.1

    /// How long a type clip runs to type `text` at ``typingInterval``, at least ``defaultDuration``.
    static func typingDuration(for text: String) -> Double {
        max(defaultDuration, pressDuration + 2 * typingMargin + Double(text.count) * typingInterval)
    }

    /// How much of ``text`` is typed at `time`: none before typing starts, all of it from when it ends,
    /// and evenly between.
    func typedText(at time: Double) -> String {
        guard action == .type, let text, !text.isEmpty else { return "" }
        let start = range.lowerBound + Self.pressDuration + Self.typingMargin
        let end = max(start, range.upperBound - Self.typingMargin)
        guard time >= start else { return "" }
        guard time < end else { return text }
        let count = Int((time - start) / (end - start) * Double(text.count)) + 1
        return String(text.prefix(min(count, text.count)))
    }
}
