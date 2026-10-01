//
//  CameraPath.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import Foundation

/// Where the camera looks over time, sampled at a fixed rate so that a frame's lookup is an index
/// and a lerp.
///
/// Integrated once per plan: a critically damped spring pulls the view towards each moment's
/// target, a zoom segment's scale and focus or else the whole frame. Scale is integrated in log
/// space, so zooming in and out by the same factor look equally fast.
nonisolated struct CameraPath: Sendable {

    /// What the camera shows: the frame magnified `scale` times around `center`.
    nonisolated struct Viewport: Equatable, Sendable {

        /// Fractions of the video's width and height from its top-left corner.
        var center: CGPoint

        var scale: Double

        static let whole = Viewport(center: CGPoint(x: 0.5, y: 0.5), scale: 1)
    }

    static let sampleRate = 120.0

    /// The spring's natural frequency, in radians per second: a move is 96% done after 0.5 s. The
    /// spring stops within 0.04 px of its target at 4K, about 1.4 s after a 2× zoom starts or ends.
    static let stiffness = 10.0

    /// The share of the view, around its centre, in which the cursor moves without the view following.
    static let deadZone = 0.5

    /// Empty when there are no zooms.
    private let samples: [Viewport]

    /// - Parameters:
    ///   - zooms: Sorted and apart.
    ///   - cursor: The cursor's positions in the video, sorted by source time, each held until the
    ///     next. Without them, a zoom that follows the cursor centres on the frame.
    ///   - duration: The recording's length in seconds.
    init(zooms: [ZoomSegment], cursor: [(time: Double, point: CGPoint)], duration: Double) {
        guard !zooms.isEmpty else {
            samples = []
            return
        }
        var centerX = Spring(position: 0.5, frequency: Self.stiffness, rate: Self.sampleRate)
        var centerY = Spring(position: 0.5, frequency: Self.stiffness, rate: Self.sampleRate)
        var logScale = Spring(position: 0, frequency: Self.stiffness, rate: Self.sampleRate)
        var zoomIndex = 0
        var cursorIndex = 0
        var followed: CGPoint?

        let last = Int((duration * Self.sampleRate).rounded(.up))
        var samples: [Viewport] = []
        samples.reserveCapacity(last + 1)
        for index in 0...last {
            let time = Double(index) / Self.sampleRate
            while zoomIndex < zooms.count, zooms[zoomIndex].range.upperBound <= time {
                zoomIndex += 1
                followed = nil
            }
            while cursorIndex + 1 < cursor.count, cursor[cursorIndex + 1].time <= time {
                cursorIndex += 1
            }

            var target = Viewport.whole
            if zoomIndex < zooms.count, zooms[zoomIndex].range.contains(time) {
                target = Self.target(of: zooms[zoomIndex], cursor: cursor.isEmpty ? nil : cursor[cursorIndex].point, followed: &followed)
            }

            let scale = max(exp(logScale.position), 1)
            samples.append(Viewport(center: ZoomSegment.clamped(CGPoint(x: centerX.position, y: centerY.position), scale: scale), scale: scale))

            centerX.advance(to: target.center.x)
            centerY.advance(to: target.center.y)
            logScale.advance(to: log(target.scale))
        }
        self.samples = samples
    }

    /// The view at source time `time`, clamped to the recording.
    func viewport(at time: Double) -> Viewport {
        guard let last = samples.indices.last else { return .whole }
        let position = min(max(time * Self.sampleRate, 0), Double(last))
        let index = Int(position)
        guard index < last else { return samples[last] }
        let fraction = position - Double(index)
        let (before, after) = (samples[index], samples[index + 1])
        return Viewport(
            center: CGPoint(
                x: before.center.x + (after.center.x - before.center.x) * fraction,
                y: before.center.y + (after.center.y - before.center.y) * fraction
            ),
            scale: before.scale + (after.scale - before.scale) * fraction
        )
    }

    /// Where `zoom` looks: at its fixed focus, or following `cursor` from `followed`, which it
    /// updates. Without a cursor, at the frame's centre.
    private static func target(of zoom: ZoomSegment, cursor: CGPoint?, followed: inout CGPoint?) -> Viewport {
        switch zoom.focus {
        case .fixed(let center):
            return Viewport(center: ZoomSegment.clamped(center, scale: zoom.scale), scale: zoom.scale)
        case .followCursor:
            guard let cursor else { return Viewport(center: Viewport.whole.center, scale: zoom.scale) }
            let center = following(cursor, from: followed, scale: zoom.scale)
            followed = center
            return Viewport(center: center, scale: zoom.scale)
        }
    }

    /// The view's centre, moved from `center` just enough to bring `cursor` within the dead zone,
    /// and kept inside the frame. Without a centre yet, the cursor.
    static func following(_ cursor: CGPoint, from center: CGPoint?, scale: Double) -> CGPoint {
        let reach = deadZone / (2 * scale)
        let center = center ?? cursor
        return ZoomSegment.clamped(
            CGPoint(x: min(max(center.x, cursor.x - reach), cursor.x + reach), y: min(max(center.y, cursor.y - reach), cursor.y + reach)),
            scale: scale
        )
    }
}
