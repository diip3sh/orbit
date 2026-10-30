//
//  VideoOverlay.swift
//  Reco
//

import CoreGraphics
import Foundation

/// Text, a picture or an arrow over the video for a while (spec 0023, section 3). It's over the zoom, so it stays where
/// it's put. Times are source seconds, so cuts and speeds never invalidate it.
nonisolated struct VideoOverlay: Codable, Equatable, Identifiable, Sendable {

    nonisolated enum Kind: Codable, Equatable, Sendable {
        case text(TextOverlayStyle)

        /// A security-scoped bookmark to the picture the user chose, as ``CanvasStyle/imageBookmark``.
        case image(bookmark: Data)

        case arrow(ArrowOverlayStyle)
    }

    var id = UUID()
    var range: Range<Double>

    /// Overlays overlap in time only on different lanes, and a higher lane draws over a lower one.
    var lane = 0

    /// As fractions of the video (the crop, when there is one) from its top-left corner.
    var frame: CGRect

    var kind: Kind

    /// How many lanes there are.
    static let laneCount = 3

    /// An overlay added by hand lasts this long on screen, if there's room.
    static let defaultDuration = 3.0

    /// The smallest share of the video's width and height a frame covers.
    static let minimumSize = 0.02

    /// Where a text overlay is added: the middle of the frame.
    static let defaultTextFrame = CGRect(x: 0.3, y: 0.42, width: 0.4, height: 0.16)

    /// Where an arrow is added.
    static let defaultArrowFrame = CGRect(x: 0.35, y: 0.35, width: 0.3, height: 0.3)

    /// A picture's frame is its shape, at most this share of the video on either side.
    static let defaultImageShare = 0.4

    /// The text's style when it's a text overlay.
    var textStyle: TextOverlayStyle? {
        get {
            guard case .text(let style) = kind else { return nil }
            return style
        }
        set {
            if let newValue { kind = .text(newValue) }
        }
    }

    /// The arrow's style when it's an arrow.
    var arrowStyle: ArrowOverlayStyle? {
        get {
            guard case .arrow(let style) = kind else { return nil }
            return style
        }
        set {
            if let newValue { kind = .arrow(newValue) }
        }
    }

    /// What it's called on the timeline: a text overlay's text.
    var title: String {
        switch kind {
        case .text(let style): style.text
        case .image: "Image"
        case .arrow: "Arrow"
        }
    }

    var symbol: String {
        switch kind {
        case .text: "textformat"
        case .image: "photo"
        case .arrow: "arrow.up.right"
        }
    }

    /// A picture of `pictureSize` pixels's frame in the middle of a `videoSize` video, in the picture's shape.
    static func imageFrame(pictureSize: CGSize, videoSize: CGSize) -> CGRect {
        let scale = min(defaultImageShare * videoSize.width / pictureSize.width, defaultImageShare * videoSize.height / pictureSize.height)
        let width = max(pictureSize.width * scale / videoSize.width, minimumSize)
        let height = max(pictureSize.height * scale / videoSize.height, minimumSize)
        return CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }

    /// A point of the frame, as fractions of it, as fractions of the video.
    func videoPoint(of point: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + point.x * frame.width, y: frame.minY + point.y * frame.height)
    }

    /// This arrow with its ends at `start` and `end`, fractions of the video, kept inside it. The frame is what's around
    /// them, at least ``minimumSize`` on each side, so a level arrow still has something to grab.
    func arrow(from start: CGPoint, to end: CGPoint) -> VideoOverlay {
        guard var style = arrowStyle else { return self }
        let inside = { (point: CGPoint) in CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1)) }
        let (start, end) = (inside(start), inside(end))
        let (width, height) = (max(abs(end.x - start.x), Self.minimumSize), max(abs(end.y - start.y), Self.minimumSize))
        let frame = RegionDrag.clamped(
            CGRect(x: (start.x + end.x - width) / 2, y: (start.y + end.y - height) / 2, width: width, height: height), minimumSize: Self.minimumSize
        )
        let share = { (point: CGPoint) in CGPoint(x: (point.x - frame.minX) / frame.width, y: (point.y - frame.minY) / frame.height) }
        style.start = share(start)
        style.end = share(end)
        var overlay = self
        overlay.frame = frame
        overlay.kind = .arrow(style)
        return overlay
    }
}

/// An overlay lane's clip.
nonisolated extension VideoOverlay: TimelineClip {
    static var minimumDuration: Double { 0.25 }
}
