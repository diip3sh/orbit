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
/// target, a zoom segment's scale and focus or else the base view, the whole frame or (filling a canvas of
/// another shape) the largest part of it in the canvas's shape, following the cursor. Scale is integrated in
/// log space, so zooming in and out by the same factor look equally fast.
nonisolated struct CameraPath: Sendable {

    /// What the camera shows: the base view magnified `scale` times around `center`.
    nonisolated struct Viewport: Equatable, Sendable {

        /// Fractions of the video's width and height from its top-left corner.
        var center: CGPoint

        var scale: Double

        static let whole = Viewport(center: CGPoint(x: 0.5, y: 0.5), scale: 1)
    }

    static let sampleRate = 120.0

    /// The share of the view, around its centre, in which the cursor moves without the view following.
    static let deadZone = 0.5

    /// The base view when the canvas shows the whole video.
    static let wholeVideo = CGSize(width: 1, height: 1)

    /// The part of the video shown at 1×, as fractions of it (``CanvasLayout/baseView``).
    let baseView: CGSize

    /// Empty when there are no zooms and the base view is the whole video.
    private let samples: [Viewport]

    /// Times are the output's (``RenderPlan`` maps them), so a zoom eases at the same pace at any speed.
    /// - Parameters:
    ///   - zooms: Sorted and apart.
    ///   - cursor: The cursor's positions in the video, sorted by time, each held until the
    ///     next. Without them, a zoom that follows the cursor centres on the frame.
    ///   - duration: The output's length in seconds.
    ///   - stiffness: The spring's natural frequency, in radians per second (``ZoomMotion/frequency``).
    ///   - baseView: The part of the video shown at 1×; smaller than the whole, it follows the cursor between zooms.
    init(
        zooms: [ZoomSegment], cursor: [(time: Double, point: CGPoint)], duration: Double,
        stiffness: Double = ZoomMotion.smooth.frequency, baseView: CGSize = wholeVideo
    ) {
        self.baseView = baseView
        let follows = baseView != Self.wholeVideo
        guard !zooms.isEmpty || follows else {
            samples = []
            return
        }
        // A base view that follows starts on the cursor, not easing there from the centre
        let start = follows && !cursor.isEmpty ? Self.following(cursor[0].point, from: nil, scale: 1, in: baseView) : Viewport.whole.center
        var centerX = Spring(position: start.x, frequency: stiffness, rate: Self.sampleRate)
        var centerY = Spring(position: start.y, frequency: stiffness, rate: Self.sampleRate)
        var logScale = Spring(position: 0, frequency: stiffness, rate: Self.sampleRate)
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

            let point = cursor.isEmpty ? nil : cursor[cursorIndex].point
            var target = Viewport.whole
            if zoomIndex < zooms.count, zooms[zoomIndex].range.contains(time) {
                target = Self.target(of: zooms[zoomIndex], cursor: point, followed: &followed, in: baseView)
            } else if follows, let point {
                target.center = Self.following(point, from: followed, scale: 1, in: baseView)
                followed = target.center
            }

            let scale = max(exp(logScale.position), 1)
            samples.append(Viewport(
                center: ZoomSegment.clamped(CGPoint(x: centerX.position, y: centerY.position), scale: scale, in: baseView), scale: scale
            ))

            centerX.advance(to: target.center.x)
            centerY.advance(to: target.center.y)
            logScale.advance(to: log(target.scale))
        }
        self.samples = samples
    }

    /// The view at output time `time`, clamped to the output.
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
    private static func target(of zoom: ZoomSegment, cursor: CGPoint?, followed: inout CGPoint?, in view: CGSize) -> Viewport {
        switch zoom.focus {
        case .fixed(let center):
            return Viewport(center: ZoomSegment.clamped(center, scale: zoom.scale, in: view), scale: zoom.scale)
        case .followCursor:
            guard let cursor else { return Viewport(center: Viewport.whole.center, scale: zoom.scale) }
            let center = following(cursor, from: followed, scale: zoom.scale, in: view)
            followed = center
            return Viewport(center: center, scale: zoom.scale)
        }
    }

    /// The view's centre, moved from `center` just enough to bring `cursor` within the dead zone,
    /// and kept inside the frame. Without a centre yet, the cursor. `view` is the base view.
    static func following(_ cursor: CGPoint, from center: CGPoint?, scale: Double, in view: CGSize = wholeVideo) -> CGPoint {
        let (reachX, reachY) = (deadZone * view.width / (2 * scale), deadZone * view.height / (2 * scale))
        let center = center ?? cursor
        return ZoomSegment.clamped(
            CGPoint(x: min(max(center.x, cursor.x - reachX), cursor.x + reachX), y: min(max(center.y, cursor.y - reachY), cursor.y + reachY)),
            scale: scale, in: view
        )
    }
}
