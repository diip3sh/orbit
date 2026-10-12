//
//  MaskSegment.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Rectangles of the content hidden for a while (spec 0004, N8): blurred, pixelated, or the only parts not dimmed.
/// They're on the content, so they zoom and pan with it. Times are source seconds.
nonisolated struct MaskSegment: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var range: Range<Double>

    /// As fractions of the video (the crop, when there is one) from its top-left corner; at least one. Several, since
    /// a frame often shows more than one thing to hide at once and masks are apart in time.
    var rects = [Self.defaultRect]

    var kind = Kind.blur

    nonisolated enum Kind: String, CaseIterable, Codable, Sendable {
        case blur, pixelate, spotlight

        var title: String {
            switch self {
            case .blur: "Blur"
            case .pixelate: "Pixelate"
            case .spotlight: "Spotlight"
            }
        }

        var symbol: String {
            switch self {
            case .blur: "drop"
            case .pixelate: "squareshape.split.3x3"
            case .spotlight: "light.max"
            }
        }
    }

    /// A rectangle added by hand: the middle of the frame.
    static let defaultRect = CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3)

    /// A mask added by hand lasts this long, if there's room.
    static let defaultDuration = 3.0

    /// The smallest share of the video's width and height a mask covers: about a line of small text at 1080p.
    static let minimumSize = 0.02
}

/// A mask lane's clip.
nonisolated extension MaskSegment: TimelineClip {
    static var minimumDuration: Double { 0.25 }
}

nonisolated extension [MaskSegment] {

    /// A mask at `time`, `nil` inside another or where there's no room.
    func newMask(at time: Double, duration: Double) -> MaskSegment? {
        room(at: time, length: MaskSegment.defaultDuration, duration: duration).map { MaskSegment(range: $0) }
    }
}
