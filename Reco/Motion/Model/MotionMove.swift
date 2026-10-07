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
        // UI and any layer
        case rise, slideIn, tilt, focus, detach, stateChange
        // Groups: their layers one after another
        case cascade
        // Cameras
        case hold, push, pan, pullBack, drift

        var isCamera: Bool {
            [.hold, .push, .pan, .pullBack, .drift].contains(self)
        }

        var needsText: Bool {
            [.blurWipe, .lineMask, .wordByWord, .type, .roll].contains(self)
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

    /// How far or how much, 1 for the grammar's own amount; for a pan, how much closer it ends.
    var intensity: Double?

    /// Where a drift, a slide in or an exit goes.
    var direction: Direction?

    /// A roll's words, in turn after the text's last word.
    var words: [String]?

    /// What a focus frames, in fractions of the layer from its top-left corner.
    var region: CGRect?

    /// Where a pan ends, the point the camera looks at in canvas pixels; coded `to`.
    var target: CGPoint?

    init(_ kind: Kind, start: Double? = nil, duration: Double? = nil) {
        self.kind = kind
        self.start = start
        self.duration = duration
    }
}

// MARK: - Validation

nonisolated extension MotionMove {

    private var hasValidNumbers: Bool {
        let isNegative = [start, duration, intensity].contains { $0.map { !$0.isFinite || $0 < 0 } ?? false }
        return !isNegative && duration != 0 && intensity != 0
    }

    /// What's wrong with this move on a layer showing `content`, or on a camera when `nil`.
    func problem(on content: LayerContent?) -> String? {
        guard hasValidNumbers else { return "start must be 0 or more, duration and intensity more than 0." }
        let isText = if case .text = content { true } else { false }
        let isGroup = if case .group = content { true } else { false }
        if kind.isCamera != (content == nil) {
            return content == nil ? "\(kind.rawValue) moves a layer, not a camera." : "\(kind.rawValue) moves a camera, not a layer."
        }
        switch kind {
        case let kind where kind.needsText && !isText: return "\(kind.rawValue) needs a text layer."
        case .cascade where !isGroup: return "cascade needs a group: its layers enter one after another."
        case .roll where words?.isEmpty ?? true: return "roll needs words."
        case .pan where target == nil: return "pan needs to: the point to look at."
        case .focus where !(region.map { CGRect(x: 0, y: 0, width: 1, height: 1).contains($0) && !$0.isEmpty } ?? false):
            return "focus needs a region inside the layer, in fractions of its size."
        default: return nil
        }
    }
}

// MARK: - Codable

nonisolated extension MotionMove: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind = "move"
        case start, duration, intensity, direction, words, region
        case target = "to"
    }
}
