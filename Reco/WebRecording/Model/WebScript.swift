//
//  WebScript.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A scripted take of a web page: where the cursor goes, what it clicks and how the page scrolls,
/// over time. Rendered frame by frame into a recording with telemetry (spec 0005).
nonisolated struct WebScript: Codable, Equatable, Sendable {
    var url: URL?

    /// The page's layout size, in CSS pixels.
    var viewport = Viewport.desktop.size

    /// Video pixels per CSS pixel.
    var scale = 2

    /// The video's length in seconds.
    var duration = 10.0

    /// The Cursor lane, sorted and apart.
    var pointer: [PointerClip] = []

    /// The Scroll lane, sorted and apart.
    var scrolls: [ScrollClip] = []

    /// Selectors of what's hidden on every page of the take, like a cookie banner or a chat button;
    /// `nil` for nothing (scripts saved before it have none).
    var hide: [String]?

    static let frameRate = 60

    /// The shortest a script can be, in seconds.
    static let minimumDuration = 1.0

    /// The longest a script can be, in seconds.
    static let maximumDuration = 120.0

    /// The web page `text` names, or `nil` when it names none: `https://` is added when it has no
    /// scheme, `http://` for local servers.
    static func url(from text: String) -> URL? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let hasScheme = text.prefixMatch(of: /[a-zA-Z][a-zA-Z0-9+.\-]*:\/\//) != nil
        let host = text.prefix { !":/?#".contains($0) }.lowercased()
        let isLocal = host == "localhost" || host == "127.0.0.1"
        let address = hasScheme ? text : (isLocal ? "http://" : "https://") + text
        guard let url = URL(string: address), ["http", "https"].contains(url.scheme?.lowercased()), url.host() != nil else {
            return nil
        }
        return url
    }

    var videoSize: CGSize {
        CGSize(width: viewport.width * CGFloat(scale), height: viewport.height * CGFloat(scale))
    }

    var frameCount: Int {
        Int((duration * Double(Self.frameRate)).rounded())
    }

    /// The shortest the script can be made without cutting a clip.
    var minimumAllowedDuration: Double {
        max(Self.minimumDuration, pointer.last?.range.upperBound ?? 0, scrolls.last?.range.upperBound ?? 0)
    }

    /// Common viewports, in CSS pixels.
    nonisolated enum Viewport: String, CaseIterable, Sendable {
        case desktop
        case laptop
        case tablet
        case phone

        var size: CGSize {
            switch self {
            case .desktop: CGSize(width: 1440, height: 900)
            case .laptop: CGSize(width: 1280, height: 800)
            case .tablet: CGSize(width: 834, height: 1194)
            case .phone: CGSize(width: 390, height: 844)
            }
        }
    }
}

// MARK: - Timeline

nonisolated extension WebScript {

    /// Where the cursor is at a moment.
    enum PointerPosition: Equatable, Sendable {

        /// On the target, following it, during a clip.
        case following(WebTarget)

        /// Still, where it was when the clip on this target ended, while the page may scroll under it,
        /// or in the middle of the view before the first clip.
        case resting(WebTarget)

        /// On its way from where it rested to the next target. `progress` is eased, from 0 to 1.
        case travelling(start: WebTarget, end: WebTarget, progress: Double)
    }

    /// A press or release of the button, for a click clip.
    struct Press: Equatable, Sendable {
        var time: Double
        var isDown: Bool
        var target: WebTarget
    }

    /// The longest the cursor takes to travel between two clips; a longer gap is spent waiting first.
    static let maximumTravel = 1.0

    /// How far a travelling cursor bows out from the straight line, as a share of the distance.
    static let travelArc = 0.1

    /// How far past a time a press may be and still count as at it: a release at 0.2 + 0.1 s is
    /// 0.30000000000000004 s, and belongs on the frame at 0.3 s.
    static let pressTolerance = 1e-9

    /// Where the page is scrolled to at `time`: eased along the clip playing then, or where the last
    /// one ended.
    func scrollOffset(at time: Double) -> CGPoint {
        var offset = CGPoint.zero
        for clip in scrolls {
            guard time < clip.range.upperBound else {
                offset = clip.offset
                continue
            }
            guard time > clip.range.lowerBound else { break }
            let progress = clip.easing((time - clip.range.lowerBound) / (clip.range.upperBound - clip.range.lowerBound))
            return CGPoint(x: offset.x + (clip.offset.x - offset.x) * progress, y: offset.y + (clip.offset.y - offset.y) * progress)
        }
        return offset
    }

    /// Where the cursor is at `time`, or `nil` when the Cursor lane is empty. ``PointerTrack`` turns
    /// it into a location.
    ///
    /// Before the first clip the cursor waits in the middle of the view, then travels to the first
    /// target, so a take opens on the whole page and its first stop is an arrival, which the editor
    /// zooms on.
    func pointerPosition(at time: Double) -> PointerPosition? {
        guard let first = pointer.first else { return nil }
        guard let index = pointer.lastIndex(where: { $0.range.lowerBound <= time }) else {
            let entry = WebTarget(point: CGPoint(x: viewport.width / 2, y: viewport.height / 2))
            let travel = min(first.range.lowerBound, Self.maximumTravel)
            let departure = first.range.lowerBound - travel
            guard time > departure, travel > 0 else { return .resting(entry) }
            return .travelling(start: entry, end: first.target, progress: Easing.easeInOut((time - departure) / travel))
        }
        let clip = pointer[index]
        guard time >= clip.range.upperBound else { return .following(clip.target) }
        guard index + 1 < pointer.count else { return .resting(clip.target) }

        let next = pointer[index + 1]
        let travel = min(next.range.lowerBound - clip.range.upperBound, Self.maximumTravel)
        let departure = next.range.lowerBound - travel
        guard time > departure, travel > 0 else { return .resting(clip.target) }
        return .travelling(start: clip.target, end: next.target, progress: Easing.easeInOut((time - departure) / travel))
    }

    /// The presses and releases after `start` and up to and including `end`, give or take
    /// ``pressTolerance``, in time order.
    func presses(after start: Double, through end: Double) -> [Press] {
        pointer.filter { $0.action == .click }.flatMap { clip in
            let press = clip.range.lowerBound
            let release = min(press + PointerClip.pressDuration, clip.range.upperBound)
            return [Press(time: press, isDown: true, target: clip.target), Press(time: release, isDown: false, target: clip.target)]
        }
        .filter { $0.time > start + Self.pressTolerance && $0.time <= end + Self.pressTolerance }
    }

    /// The characters typed after `start` and up to and including `end`, give or take
    /// ``pressTolerance``, in time order, each with the target it's typed into.
    func keystrokes(after start: Double, through end: Double) -> [(character: Character, target: WebTarget)] {
        pointer.flatMap { clip in
            clip.keystrokes.filter { $0.time > start + Self.pressTolerance && $0.time <= end + Self.pressTolerance }.map { ($0.character, clip.target) }
        }
    }

    /// The point `progress` of the way from `start` to `end` along a gentle arc that bows to the left
    /// of the direction of travel, by ``travelArc`` of the distance at its middle.
    static func travelPoint(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        // Twice the bow, since a quadratic Bézier reaches half-way to its control point
        let bow = 2 * travelArc
        let control = CGPoint(x: middle.x + (end.y - start.y) * bow, y: middle.y - (end.x - start.x) * bow)
        // The Bézier as offsets from the start, so a travel to where the cursor already is stays put
        let towardsControl = 2 * (1 - progress) * progress
        let towardsEnd = progress * progress
        return CGPoint(
            x: start.x + towardsControl * (control.x - start.x) + towardsEnd * (end.x - start.x),
            y: start.y + towardsControl * (control.y - start.y) + towardsEnd * (end.y - start.y)
        )
    }
}
