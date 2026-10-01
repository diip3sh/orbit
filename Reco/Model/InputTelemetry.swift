//
//  InputTelemetry.swift
//  Reco
//
//  Created by Diip3sh on 25.09.26.
//

import CoreGraphics
import Foundation

/// Input telemetry saved next to a recording as a `.telemetry.json` sidecar, for editing features
/// such as auto-zoom, cursor smoothing, click highlights and keystroke overlays.
///
/// Times are seconds on the video timeline, where 0 is the first frame of the file. Paused time is
/// cut from it, as it is from the video. Locations are global CoreGraphics points - top-left origin
/// on the primary display, Y increasing downwards - the space `CGDisplayBounds` uses.
/// ``videoPixel(for:geometry:)`` maps a location into the video with the ``geometry`` entry in
/// effect at its time.
nonisolated struct InputTelemetry: Codable, Equatable, Sendable {

    /// Bumped whenever the file layout changes incompatibly.
    var version = 3

    /// The versions this build reads. Version 2 files have no cursor sprites or shapes.
    static let supportedVersions = 2...3

    var capture: Capture

    /// Whether keystrokes were recorded. False when Input Monitoring was not granted.
    var keystrokesAvailable: Bool

    /// Where the captured content was on screen and in the video, whenever that changed.
    var geometry: [Geometry] = []
    var cursor: [CursorSample] = []
    var clicks: [Click] = []
    var scrolls: [Scroll] = []
    var keys: [Key] = []

    /// Each distinct cursor image, stored once and referenced by ``cursorShapes``.
    var cursorSprites: [CursorSprite] = []

    /// The cursor's appearance, recorded whenever it changed. Each entry applies until the next.
    var cursorShapes: [CursorShape] = []

    // MARK: - Types

    /// What kind of content ``Capture`` describes.
    nonisolated enum CaptureKind: String, Codable, Sendable {
        case display
        case window
        case area

        /// A web page rendered from a script (spec 0005). Locations are its viewport's CSS pixels.
        case web
    }

    /// What was recorded.
    nonisolated struct Capture: Codable, Equatable, Sendable {
        var kind: CaptureKind

        /// The video's dimensions in pixels.
        var videoSize: CGSize

        /// Whether the system cursor is drawn into the video. When false, an editor draws it from
        /// ``InputTelemetry/cursor`` and the cursor sprites. Read as true from files without it.
        var cursorInVideo = true
    }

    /// ScreenCaptureKit's `SCStreamFrameInfo` metadata, recorded at the first complete frame and
    /// whenever a value changed, e.g. when a captured window moved or resized.
    ///
    /// Each entry applies until the next one; the first also applies before its time. Values are
    /// stored raw so ``InputTelemetry/videoPixel(for:geometry:)`` can be corrected without
    /// re-recording should ScreenCaptureKit's semantics differ from its documentation.
    nonisolated struct Geometry: Codable, Equatable, Sendable {
        var time: Double

        /// Where the captured content is on screen, in global points (`screenRect`).
        var screenRect: CGRect

        /// Where the content is drawn in the video frame, in frame points (`contentRect`).
        var contentRect: CGRect

        /// The captured windows' bounds in the video frame, in frame points (`boundingRect`),
        /// when ScreenCaptureKit reports it.
        var boundingRect: CGRect?

        /// How much the content was scaled to fit the frame (`contentScale`).
        var contentScale: CGFloat

        /// Pixels per frame point (`scaleFactor`).
        var scaleFactor: CGFloat
    }

    /// The cursor position, sampled whenever it changed.
    nonisolated struct CursorSample: Codable, Equatable, Sendable {
        var time: Double
        var location: CGPoint
    }

    nonisolated enum MouseButton: String, Codable, Sendable {
        case left
        case right
        case other
    }

    nonisolated struct Click: Codable, Equatable, Sendable {
        var time: Double
        var location: CGPoint
        var button: MouseButton
        var isDown: Bool
        var clickCount: Int
    }

    nonisolated struct Scroll: Codable, Equatable, Sendable {
        var time: Double
        var location: CGPoint

        /// Points on trackpads and Magic Mouse, lines on classic scroll wheels.
        var delta: CGVector
    }

    /// A key press. Only the physical key and modifiers are stored, never the typed characters.
    nonisolated struct Key: Codable, Equatable, Sendable {
        var time: Double
        var keyCode: Int
        var modifiers: [String]
        var isRepeat: Bool
    }

    /// A cursor image, so an editor can redraw the cursor on a video recorded without it.
    nonisolated struct CursorSprite: Codable, Equatable, Sendable {
        var id: Int

        /// The standard cursor this image is, or `nil` for any other, e.g. an app's own cursor.
        var kind: CursorKind?

        /// The image's size in points.
        var size: CGSize

        /// The click point, in points from the image's top-left corner.
        var hotspot: CGPoint

        /// The image at its highest resolution, as PNG. Base64 in JSON.
        var png: Data
    }

    /// The cursor switching to the ``CursorSprite`` with id `sprite`.
    nonisolated struct CursorShape: Codable, Equatable, Sendable {
        var time: Double
        var sprite: Int
    }

    // MARK: - Conversion

    /// Share of a window shadow's vertical extent that sits above the window; the rest is below.
    ///
    /// ponytail: measured on macOS 27 (39.2 of 112 pt for an active window). ScreenCaptureKit only
    /// reports the shadow's total size, so re-measure if Apple changes window shadows.
    static let shadowTopFraction: CGFloat = 0.35

    /// Maps a global location into video pixels (top-left origin) with the geometry in effect:
    /// `pixel = (contentRect.origin + (location - screenRect.origin + shadowInset) * contentScale) * scaleFactor`.
    ///
    /// `screenRect` is the bare content on screen; `contentRect` is where it is drawn in the frame,
    /// scaled by `contentScale` into frame points, each `scaleFactor` pixels wide. For windows
    /// captured with their shadow, `contentRect` also covers the shadow, so the window sits inset
    /// by half the extra width horizontally and by ``shadowTopFraction`` of the extra height.
    static func videoPixel(for location: CGPoint, geometry: Geometry) -> CGPoint {
        let frameOrigin = geometry.contentRect.origin
        let screenOrigin = geometry.screenRect.origin
        let shadowWidth = max(geometry.contentRect.width / geometry.contentScale - geometry.screenRect.width, 0)
        let shadowHeight = max(geometry.contentRect.height / geometry.contentScale - geometry.screenRect.height, 0)
        let insetX = shadowWidth / 2
        let insetY = shadowHeight * shadowTopFraction
        return CGPoint(
            x: (frameOrigin.x + (location.x - screenOrigin.x + insetX) * geometry.contentScale) * geometry.scaleFactor,
            y: (frameOrigin.y + (location.y - screenOrigin.y + insetY) * geometry.contentScale) * geometry.scaleFactor
        )
    }

    /// The ``geometry`` entry in effect at `time`: the last one at or before it, or the first.
    func geometry(at time: Double) -> Geometry? {
        guard !geometry.isEmpty else { return nil }
        return geometry[max(geometry.partitioningIndex { $0.time > time } - 1, 0)]
    }

    /// Where `location` was in the video at `time`, as fractions of its width and height from the
    /// top-left corner, or `nil` without geometry.
    func normalizedVideoPoint(for location: CGPoint, at time: Double) -> CGPoint? {
        guard let geometry = geometry(at: time) else { return nil }
        let pixel = Self.videoPixel(for: location, geometry: geometry)
        return CGPoint(x: pixel.x / capture.videoSize.width, y: pixel.y / capture.videoSize.height)
    }

    /// Video pixels per screen point, at the lowest it was during the recording: 2 for a Retina
    /// display recorded at native resolution. `nil` without geometry.
    var pixelsPerPoint: CGFloat? {
        geometry.map { $0.contentScale * $0.scaleFactor }.min()
    }

    /// Converts a host-clock time into video time, or `nil` when it falls outside the video.
    /// - Parameters:
    ///   - hostTime: Seconds on the host clock, which ScreenCaptureKit sample timestamps and
    ///     `NSEvent.timestamp` share.
    ///   - anchor: The host time of the video's first frame.
    ///   - duration: The video's length in seconds.
    ///   - pauses: Host-time intervals cut from the video. Times inside one are dropped, later times
    ///     move earlier by the paused time before them.
    static func videoTime(hostTime: Double, anchor: Double, duration: Double, pauses: [Range<Double>] = []) -> Double? {
        guard !pauses.contains(where: { $0.contains(hostTime) }) else { return nil }
        let paused = pauses.filter { $0.upperBound <= hostTime }.reduce(0) { $0 + $1.upperBound - $1.lowerBound }
        let time = hostTime - anchor - paused
        return time >= 0 && time <= duration ? time : nil
    }

    /// Flips an AppKit screen location (bottom-left origin of the primary display) into global
    /// CoreGraphics points (top-left origin).
    static func topLeft(_ location: CGPoint, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: location.x, y: primaryScreenHeight - location.y)
    }

    /// Names the modifier keys held in `flags`, in the order macOS displays them.
    static func modifierNames(_ flags: CGEventFlags) -> [String] {
        let names: [(flag: CGEventFlags, name: String)] = [
            (.maskControl, "control"),
            (.maskAlternate, "option"),
            (.maskShift, "shift"),
            (.maskCommand, "command"),
            (.maskSecondaryFn, "function"),
            (.maskAlphaShift, "capsLock")
        ]
        return names.filter { flags.contains($0.flag) }.map(\.name)
    }

    /// The sidecar for a recording: same folder and base name, `.telemetry.json` extension.
    static func sidecarURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("telemetry").appendingPathExtension("json")
    }

    /// Returns a copy with every time moved onto the video timeline and events outside it dropped.
    ///
    /// Paused time is cut and events during a pause are dropped. The last cursor position, cursor
    /// shape and geometry before the first frame, or during a pause, are kept at the point where the
    /// video starts or resumes, so values that do not change afterwards are still known.
    func rebased(anchor: Double, duration: Double, pauses: [Range<Double>] = []) -> InputTelemetry {
        var copy = self
        copy.geometry = Self.rebaseTrack(geometry, time: \.time, anchor: anchor, duration: duration, pauses: pauses)
        copy.cursor = Self.rebaseTrack(cursor, time: \.time, anchor: anchor, duration: duration, pauses: pauses)
        copy.cursorShapes = Self.rebaseTrack(cursorShapes, time: \.time, anchor: anchor, duration: duration, pauses: pauses)
        copy.clicks = Self.rebase(clicks, time: \.time, anchor: anchor, duration: duration, pauses: pauses)
        copy.scrolls = Self.rebase(scrolls, time: \.time, anchor: anchor, duration: duration, pauses: pauses)
        copy.keys = Self.rebase(keys, time: \.time, anchor: anchor, duration: duration, pauses: pauses)
        return copy
    }

    private static func rebase<Event>(
        _ events: [Event], time: WritableKeyPath<Event, Double>, anchor: Double, duration: Double, pauses: [Range<Double>]
    ) -> [Event] {
        events.compactMap { event in
            guard let videoTime = videoTime(hostTime: event[keyPath: time], anchor: anchor, duration: duration, pauses: pauses) else {
                return nil
            }
            var event = event
            event[keyPath: time] = videoTime
            return event
        }
    }

    /// Like `rebase`, but a sample from before the first frame or during a pause moves to where the
    /// video starts or resumes, and only the last sample at any one time is kept. A pause still in
    /// progress at stop ends at infinity, so its samples fall off the end.
    private static func rebaseTrack<Sample>(
        _ samples: [Sample], time: WritableKeyPath<Sample, Double>, anchor: Double, duration: Double, pauses: [Range<Double>]
    ) -> [Sample] {
        let held = samples.map { sample in
            var sample = sample
            let hostTime = sample[keyPath: time]
            sample[keyPath: time] = pauses.first { $0.contains(hostTime) }?.upperBound ?? max(hostTime, anchor)
            return sample
        }

        var rebased: [Sample] = []
        for sample in rebase(held, time: time, anchor: anchor, duration: duration, pauses: pauses) {
            if rebased.last?[keyPath: time] == sample[keyPath: time] {
                rebased.removeLast()
            }
            rebased.append(sample)
        }
        return rebased
    }
}

// MARK: - Decoding

extension InputTelemetry {

    /// Decodes a file, rejecting versions outside ``supportedVersions`` with ``UnsupportedVersionError``.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard Self.supportedVersions.contains(version) else {
            throw UnsupportedVersionError(version: version)
        }
        capture = try container.decode(Capture.self, forKey: .capture)
        keystrokesAvailable = try container.decode(Bool.self, forKey: .keystrokesAvailable)
        geometry = try container.decode([Geometry].self, forKey: .geometry)
        cursor = try container.decode([CursorSample].self, forKey: .cursor)
        clicks = try container.decode([Click].self, forKey: .clicks)
        scrolls = try container.decode([Scroll].self, forKey: .scrolls)
        keys = try container.decode([Key].self, forKey: .keys)
        cursorSprites = try container.decodeIfPresent([CursorSprite].self, forKey: .cursorSprites) ?? []
        cursorShapes = try container.decodeIfPresent([CursorShape].self, forKey: .cursorShapes) ?? []
    }
}

extension InputTelemetry.Capture {

    /// Decodes files written before ``cursorInVideo`` existed as having the cursor in the video.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(InputTelemetry.CaptureKind.self, forKey: .kind)
        videoSize = try container.decode(CGSize.self, forKey: .videoSize)
        cursorInVideo = try container.decodeIfPresent(Bool.self, forKey: .cursorInVideo) ?? true
    }
}
