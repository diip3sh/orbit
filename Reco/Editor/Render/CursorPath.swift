//
//  CursorPath.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation

/// Where the editor draws the cursor over time, how big and how visible, integrated once per plan
/// so that a frame's lookup is a lerp and a few binary searches.
///
/// The recorded positions are smoothed by a spring sampled at 120 Hz. Around each click the path
/// glides onto the click point and passes exactly through it at the click's time, so the cursor's
/// hot spot sits on the click highlight.
nonisolated struct CursorPath: Sendable {

    static let sampleRate = 120.0

    /// A move back against the previous one, shorter than this in screen points, is jitter.
    static let jitterDistance = 2.0

    /// How long the path takes to glide onto a click point before the click, and back onto the
    /// smoothed path after it.
    static let glideDuration = 0.5
    static let returnDuration = 0.175

    /// How long a press takes to shrink the cursor to ``pressedScale``, and a release to restore it.
    static let pressDuration = 0.13
    static let pressedScale = 0.8

    /// How long the cursor must be still before it fades out, and how long a fade takes. It fades
    /// back in so that it's fully shown when it next moves or clicks.
    static let idleDelay = 2.0
    static let fadeDuration = 0.3

    /// How long the glide back to the first position takes when the cursor loops.
    static let loopDuration = 1.0

    /// The lean at full speed, in radians, and the speed in screen points per second that gives
    /// three quarters of it.
    static let maximumTilt = 0.2
    static let tiltSpeed = 1500.0

    /// The smoothed positions in Core Image pixels (bottom-left origin).
    private let samples: [CGPoint]

    /// Each click's time and the offset from the smoothed path to its point, sorted by time.
    private let clickOffsets: [(time: Double, offset: CGVector)]

    /// When a mouse button was held, sorted and apart. Empty when clicks aren't animated.
    private let presses: [Range<Double>]

    /// When the cursor is hidden, sorted and apart: idle from ``idleDelay`` after it last moved or
    /// clicked, when the style says so, and from a typed key until it next moves or clicks, as macOS
    /// hides it while you type.
    private let hidden: [Range<Double>]

    /// Video pixels per screen point times the style's size, whenever the capture geometry changed.
    private let scales: [(time: Double, scale: Double)]

    /// The cursor stays where it is from this time on. Infinite when it never stops.
    private let holdTime: Double

    /// The glide back to the position at its `home` time, or `nil` when the cursor doesn't loop.
    private let loop: (home: Double, range: Range<Double>)?

    private let tilts: Bool

    /// - Parameters:
    ///   - duration: The recording's length in seconds.
    ///   - videoHeight: The video's height in pixels, to flip positions into Core Image space.
    ///   - shown: From the first source time the output shows to the last. The whole recording when `nil`.
    /// - Returns: `nil` without cursor positions or capture geometry.
    init?(telemetry: InputTelemetry, style: CursorStyle, duration: Double, videoHeight: CGFloat, shown: Range<Double>? = nil) {
        let moves = Self.withoutJitter(telemetry.cursor)
        guard !moves.isEmpty, !telemetry.geometry.isEmpty else { return nil }
        // A web take's path is smooth already, and exact: a spring would trail the hover effects the page shows
        let samples = Self.smoothed(
            moves, geometry: telemetry.geometry, frequency: telemetry.capture.kind == .web ? nil : style.smoothing.frequency,
            duration: duration, videoHeight: videoHeight
        )

        var clickOffsets: [(time: Double, offset: CGVector)] = []
        for click in telemetry.clicks where click.time != clickOffsets.last?.time {
            guard let geometry = telemetry.geometry(at: click.time) else { continue }
            let point = RenderPlan.coreImagePoint(InputTelemetry.videoPixel(for: click.location, geometry: geometry), videoHeight: videoHeight)
            let smoothed = Self.interpolated(samples, at: click.time)
            clickOffsets.append((click.time, CGVector(dx: point.x - smoothed.x, dy: point.y - smoothed.y)))
        }

        self.samples = samples
        self.clickOffsets = clickOffsets
        presses = style.animatesClicks ? Self.presses(in: telemetry.clicks) : []
        hidden = Self.merged((style.hidesWhenIdle ? Self.idleSpans(moves: moves, clicks: telemetry.clicks) : [])
            + Self.typingSpans(keys: telemetry.keys, moves: moves, clicks: telemetry.clicks))
        scales = telemetry.geometry.map { ($0.time, $0.contentScale * $0.scaleFactor * style.size) }

        let shown = shown ?? 0..<duration
        holdTime = style.stopsBeforeEnd > 0 ? max(shown.upperBound - style.stopsBeforeEnd, shown.lowerBound) : .infinity
        let glide = min(Self.loopDuration, (shown.upperBound - shown.lowerBound) / 2)
        loop = style.loopsToStart && glide > 0 ? (shown.lowerBound, shown.upperBound - glide..<shown.upperBound) : nil
        tilts = style.tilts
    }

    /// Where the cursor's hot spot is at source time `time`, in Core Image pixels: where it was
    /// recorded, held before the end and gliding home over the last second when the style says so.
    func position(at time: Double) -> CGPoint {
        var position = recorded(at: min(time, holdTime))
        if let loop, time > loop.range.lowerBound {
            let home = recorded(at: loop.home)
            let weight = Self.ease((time - loop.range.lowerBound) / (loop.range.upperBound - loop.range.lowerBound))
            position.x += (home.x - position.x) * weight
            position.y += (home.y - position.y) * weight
        }
        return position
    }

    /// How far the cursor leans at `time`, in radians, counterclockwise: against its horizontal
    /// speed, so it leans the way it moves. Zero at rest.
    func tilt(at time: Double) -> Double {
        guard tilts else { return 0 }
        let step = 1 / Self.sampleRate
        let pixelsPerPoint = scales[max(scales.partitioningIndex { $0.time > time } - 1, 0)].scale
        let speed = (position(at: time + step).x - position(at: time - step).x) / (2 * step) / pixelsPerPoint
        return -Self.maximumTilt * tanh(speed / Self.tiltSpeed)
    }

    /// The smoothed position at `time`, on the click points at their times.
    private func recorded(at time: Double) -> CGPoint {
        var position = Self.interpolated(samples, at: time)
        let next = clickOffsets.partitioningIndex { $0.time > time }
        if next < clickOffsets.count {
            // Gliding onto the next click's point, from the previous click at the earliest
            let click = clickOffsets[next]
            let start = max(click.time - Self.glideDuration, next > 0 ? clickOffsets[next - 1].time : -.infinity)
            let weight = Self.ease((time - start) / (click.time - start))
            position.x += click.offset.dx * weight
            position.y += click.offset.dy * weight
        }
        if next > 0 {
            // Back from the last click's point, by the next click at the latest
            let click = clickOffsets[next - 1]
            let end = min(click.time + Self.returnDuration, next < clickOffsets.count ? clickOffsets[next].time : .infinity)
            let weight = 1 - Self.ease((time - click.time) / (end - click.time))
            position.x += click.offset.dx * weight
            position.y += click.offset.dy * weight
        }
        return position
    }

    /// How many video pixels each of the cursor image's points covers at `time`: the capture's
    /// pixels per point times the style's size, less while a mouse button is held.
    func scale(at time: Double) -> Double {
        let scale = scales[max(scales.partitioningIndex { $0.time > time } - 1, 0)].scale
        return scale * (1 - (1 - Self.pressedScale) * Self.ease(pressDepth(at: time)))
    }

    /// How visible the cursor is at `time`, from 0 to 1.
    func opacity(at time: Double) -> Double {
        let index = hidden.partitioningIndex { $0.lowerBound > time } - 1
        guard index >= 0, hidden[index].contains(time) else { return 1 }
        let fadingOut = 1 - (time - hidden[index].lowerBound) / Self.fadeDuration
        let fadingIn = 1 - (hidden[index].upperBound - time) / Self.fadeDuration
        return min(max(fadingOut, fadingIn, 0), 1)
    }

    /// How far into a press the cursor is at `time`, from 0 to 1: 1 once a button has been held
    /// for ``pressDuration``, and back to 0 as long after its release.
    private func pressDepth(at time: Double) -> Double {
        var depth = 0.0
        var index = presses.partitioningIndex { $0.lowerBound > time } - 1
        // A release can still be easing out when the next press starts
        while index >= 0, presses[index].upperBound + Self.pressDuration > time {
            let press = presses[index]
            let held = (min(time, press.upperBound) - press.lowerBound) / Self.pressDuration
            let released = max(time - press.upperBound, 0) / Self.pressDuration
            depth = max(depth, min(held, 1) - released)
            index -= 1
        }
        return depth
    }
}

// MARK: - Building

nonisolated extension CursorPath {

    /// The positions without jitter: a move back against the previous one, by less than
    /// ``jitterDistance``, is dropped.
    static func withoutJitter(_ samples: [InputTelemetry.CursorSample]) -> [InputTelemetry.CursorSample] {
        var kept: [InputTelemetry.CursorSample] = []
        kept.reserveCapacity(samples.count)
        var direction = CGVector.zero
        for sample in samples {
            if let last = kept.last {
                let move = CGVector(dx: sample.location.x - last.location.x, dy: sample.location.y - last.location.y)
                if move.dx * direction.dx + move.dy * direction.dy < 0, hypot(move.dx, move.dy) < jitterDistance {
                    continue
                }
                direction = move
            }
            kept.append(sample)
        }
        return kept
    }

    /// The positions held until the next and placed with the geometry in effect, followed by a
    /// spring at ``sampleRate``, or not when `frequency` is `nil`.
    /// - Parameter moves: Not empty, sorted by time.
    /// - Parameter geometry: Not empty, sorted by time.
    private static func smoothed(
        _ moves: [InputTelemetry.CursorSample], geometry: [InputTelemetry.Geometry], frequency: Double?, duration: Double, videoHeight: CGFloat
    ) -> [CGPoint] {
        var moveIndex = 0
        var geometryIndex = 0
        let start = RenderPlan.coreImagePoint(InputTelemetry.videoPixel(for: moves[0].location, geometry: geometry[0]), videoHeight: videoHeight)
        var horizontal = frequency.map { Spring(position: start.x, frequency: $0, rate: sampleRate) }
        var vertical = frequency.map { Spring(position: start.y, frequency: $0, rate: sampleRate) }

        let last = Int((duration * sampleRate).rounded(.up))
        var samples: [CGPoint] = []
        samples.reserveCapacity(last + 1)
        for index in 0...last {
            let time = Double(index) / sampleRate
            while moveIndex + 1 < moves.count, moves[moveIndex + 1].time <= time {
                moveIndex += 1
            }
            while geometryIndex + 1 < geometry.count, geometry[geometryIndex + 1].time <= time {
                geometryIndex += 1
            }
            let pixel = InputTelemetry.videoPixel(for: moves[moveIndex].location, geometry: geometry[geometryIndex])
            let target = RenderPlan.coreImagePoint(pixel, videoHeight: videoHeight)

            samples.append(CGPoint(x: horizontal?.position ?? target.x, y: vertical?.position ?? target.y))
            horizontal?.advance(to: target.x)
            vertical?.advance(to: target.y)
        }
        return samples
    }

    /// Each press to its release, merged where buttons overlap. A press without a release is left out.
    private static func presses(in clicks: [InputTelemetry.Click]) -> [Range<Double>] {
        var downs: [InputTelemetry.MouseButton: Double] = [:]
        var presses: [Range<Double>] = []
        for click in clicks {
            if click.isDown {
                downs[click.button] = downs[click.button] ?? click.time
            } else if let down = downs.removeValue(forKey: click.button) {
                presses.append(down..<click.time)
            }
        }

        var merged: [Range<Double>] = []
        for press in presses.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, press.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, press.upperBound)
            } else {
                merged.append(press)
            }
        }
        return merged
    }

    /// From ``idleDelay`` after each move or click to the next one, when that's later, and after
    /// the last one.
    /// - Parameter moves: Not empty.
    private static func idleSpans(moves: [InputTelemetry.CursorSample], clicks: [InputTelemetry.Click]) -> [Range<Double>] {
        var spans: [Range<Double>] = []
        var last: Double?
        var (move, click) = (0, 0)
        while move < moves.count || click < clicks.count {
            let time: Double
            if click == clicks.count || (move < moves.count && moves[move].time <= clicks[click].time) {
                time = moves[move].time
                move += 1
            } else {
                time = clicks[click].time
                click += 1
            }
            if let last, time - last > idleDelay {
                spans.append(last + idleDelay..<time)
            }
            last = time
        }
        if let last {
            spans.append(last + idleDelay..<Double.infinity)
        }
        return spans
    }

    /// From each key typed without ⌘ or ⌃ to the cursor's next move away or click: a shortcut leaves
    /// the cursor shown.
    /// - Parameter moves: Not empty, sorted by time.
    private static func typingSpans(keys: [InputTelemetry.Key], moves: [InputTelemetry.CursorSample], clicks: [InputTelemetry.Click]) -> [Range<Double>] {
        keys.compactMap { key -> Range<Double>? in
            guard !key.modifiers.contains("command"), !key.modifiers.contains("control") else { return nil }
            let after = moves.partitioningIndex { $0.time > key.time }
            let resting = moves[max(after - 1, 0)].location
            let moved = moves[after...].first { hypot($0.location.x - resting.x, $0.location.y - resting.y) >= jitterDistance }?.time ?? .infinity
            let clicked = clicks.first { $0.time > key.time }?.time ?? .infinity
            let end = min(moved, clicked)
            return end > key.time ? key.time..<end : nil
        }
    }

    /// `spans` sorted, with those that overlap or touch joined.
    private static func merged(_ spans: [Range<Double>]) -> [Range<Double>] {
        spans.sorted { $0.lowerBound < $1.lowerBound }.reduce(into: []) { merged, span in
            if let last = merged.last, span.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, span.upperBound)
            } else {
                merged.append(span)
            }
        }
    }

    /// `samples` at `time`, clamped to them.
    private static func interpolated(_ samples: [CGPoint], at time: Double) -> CGPoint {
        let position = min(max(time * sampleRate, 0), Double(samples.count - 1))
        let index = Int(position)
        guard index < samples.count - 1 else { return samples[index] }
        let fraction = position - Double(index)
        let (before, after) = (samples[index], samples[index + 1])
        return CGPoint(x: before.x + (after.x - before.x) * fraction, y: before.y + (after.y - before.y) * fraction)
    }

    /// Eases in and out from 0 to 1 as `progress` does, and holds outside them (smoothstep).
    private static func ease(_ progress: Double) -> Double {
        let progress = min(max(progress, 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
}
