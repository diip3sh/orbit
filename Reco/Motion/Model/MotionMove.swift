//
//  MotionMove.swift
//  Reco
//

import CoreGraphics

/// A move from the grammar on a layer or a camera: what it does is the grammar's (``MoveExpansion``),
/// when and how much is the document's. Every field but `kind` has the grammar's default.
///
/// Coded `{"move": "fadeUp", "start": 0.3}`.
nonisolated struct MotionMove: Equatable, Sendable {

    nonisolated enum Kind: String, Codable, CaseIterable, Sendable {
        // Text and any layer
        case fadeUp, blurIn, exit
        // Text only
        case blurWipe, lineMask, wordByWord, type, roll
        // Text only, motion design (spec 0014): letters springing in; typed behind a caret in the accent
        case letters, kinetic
        // UI and any layer
        case rise, slideIn, tilt, focus, detach, stateChange
        // Motion design, any layer: a pop in, a press, a pointer clicking it, particles out of it, rings out of it,
        // a long travel to `to`, a change of size, corners, colour, outline or place, and a turn into place
        case pop, press, click, burst, ripple, scroll, morph, spin
        // Motion design, a rectangle: out past the frame's corners
        case flood
        // Groups: their layers one after another
        case cascade
        // Cameras
        case hold, push, pan, pullBack, drift, whip

        var isCamera: Bool {
            [.hold, .push, .pan, .pullBack, .drift, .whip].contains(self)
        }

        var needsText: Bool {
            [.blurWipe, .lineMask, .wordByWord, .type, .roll, .letters, .kinetic].contains(self)
        }
    }

    nonisolated enum Direction: String, Codable, Sendable {
        case left, right
        case upward = "up", downward = "down"
    }

    var kind: Kind

    /// Seconds from the scene's start.
    var start: Double?

    var duration: Double?

    /// How far or how much, 1 for the grammar's own amount; for a pan, how much closer it ends; for a
    /// whip, how much closer than where it starts.
    var intensity: Double?

    /// Where a drift, a slide in or an exit goes.
    var direction: Direction?

    /// A roll's words, in turn after the text's last word.
    var words: [String]?

    /// What a focus frames, in fractions of the layer from its top-left corner.
    var region: CGRect?

    /// Where a pan or a whip ends, the point the camera looks at in canvas pixels; where a morph or a scroll
    /// puts the layer's anchor. Coded `to`.
    var target: CGPoint?

    /// What a morph changes a shape to: its size and corner radius in canvas pixels, its colour (also a burst's
    /// particles' and a ripple's rings', and a kinetic caret's), and its outline's width (0 fills it).
    var size: CGSize?
    var radius: Double?
    var color: RGBAColor?
    var stroke: Double?

    init(_ kind: Kind, start: Double? = nil, duration: Double? = nil) {
        self.kind = kind
        self.start = start
        self.duration = duration
    }
}

// MARK: - Validation

nonisolated extension MotionMove {

    private var hasValidNumbers: Bool {
        let isNegative = [start, duration, intensity, radius, stroke].contains { $0.map { !$0.isFinite || $0 < 0 } ?? false }
        let isEmpty = size.map { !($0.width > 0 && $0.height > 0 && $0.width.isFinite && $0.height.isFinite) } ?? false
        return !isNegative && !isEmpty && duration != 0 && intensity != 0
    }

    /// What's wrong with this move on a layer showing `content`, or on a camera when `nil`.
    func problem(on content: LayerContent?) -> String? {
        guard hasValidNumbers else { return "start, radius and stroke must be 0 or more; duration, intensity and size more than 0." }
        let isText = if case .text = content { true } else { false }
        let isGroup = if case .group = content { true } else { false }
        if kind.isCamera != (content == nil) {
            return content == nil ? "\(kind.rawValue) moves a layer, not a camera." : "\(kind.rawValue) moves a camera, not a layer."
        }
        switch kind {
        case let kind where kind.needsText && !isText: return "\(kind.rawValue) needs a text layer."
        case .cascade where !isGroup: return "cascade needs a group: its layers enter one after another."
        case .morph, .flood: return shapeProblem(on: content)
        default: return missingField
        }
    }

    /// A field the move can't do without.
    private var missingField: String? {
        switch kind {
        case .roll where words?.isEmpty ?? true: "roll needs words."
        case .pan where target == nil, .whip where target == nil: "\(kind.rawValue) needs to: the point to look at."
        case .focus where !(region.map { CGRect(x: 0, y: 0, width: 1, height: 1).contains($0) && !$0.isEmpty } ?? false):
            "focus needs a region inside the layer, in fractions of its size."
        case .scroll where target == nil: "scroll needs to: where the layer's anchor ends, in canvas pixels."
        default: nil
        }
    }

    /// A morph changes something, and only a rectangle's size, corners, colour and outline; a flood fills the frame
    /// from a rectangle.
    private func shapeProblem(on content: LayerContent?) -> String? {
        let rectangle = if case .shape(let shape) = content, !shape.isGlyph { true } else { false }
        if kind == .flood {
            return rectangle ? nil : "flood needs a rectangle shape: it grows out past the frame's corners."
        }
        guard size != nil || radius != nil || color != nil || stroke != nil || target != nil else {
            return "morph needs size, radius, color, stroke or to: what it changes."
        }
        return rectangle || (size == nil && radius == nil && color == nil && stroke == nil)
            ? nil : "morph changes a rectangle shape's size, radius, color and stroke; any layer's place (to)."
    }
}

// MARK: - Codable

nonisolated extension MotionMove: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind = "move"
        case start, duration, intensity, direction, words, region, size, radius, color, stroke
        case target = "to"
    }
}
