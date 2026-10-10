//
//  SeamExpansion.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A seam between two scenes as camera tracks on each, and for a push or a fade, how long the scene
/// before stays drawn under the next (HyperFrames' cut catalogue).
nonisolated enum SeamExpansion {

    nonisolated struct Effect: Sendable {
        /// On the scene before, timed from its own start.
        var outgoing: [MotionProperty: [PropertyTrack]] = [:]

        /// On the scene the seam begins.
        var incoming: [MotionProperty: [PropertyTrack]] = [:]

        var transition: Transition?
    }

    /// Both scenes drawn at once: the next one's first `duration` seconds over the end of the one before.
    nonisolated struct Transition: Equatable, Sendable {
        let seam: MotionSeam
        let duration: Double

        /// The field whose shape and colours a seam drawn in a field's language takes: the next scene's when
        /// it's of the seam's family, else the family's first pick (``MotionPlan/addSeams(of:to:)``).
        var look = MotionField.plain
        var palette: FieldPalette?

        /// How far it has gone at `time` into the next scene, eased. Light and smoke burst out of the middle and
        /// settle (eased in and out, they showed nothing for a third of the seam, then crossed the frame in 0.2 s);
        /// dither steps on at 15 frames a second, as pixel animation does (Nothing's Glyph Matrix).
        func progress(at time: Double) -> Double {
            let linear = min(max(time / duration, 0), 1)
            switch seam {
            case .glow, .ring: return MotionEasing.enter.progress(linear, duration: duration)
            case .push: return MotionEasing.move.progress(linear, duration: duration)
            case .stack: return MotionEasing.cascade.progress(linear, duration: duration)
            case .expand: return MotionEasing.morph.progress(linear, duration: duration)
            case .dither: return min((linear * duration * Self.ditherSteps).rounded(.down) / (duration * Self.ditherSteps), 1)
            default: return linear
            }
        }

        static let ditherSteps = 15.0
    }

    /// How long the seams drawn in a field's language take: long enough to see the language, as short as a
    /// whip lets the eye follow.
    static let glowDuration = 0.9
    static let ditherDuration = 0.8
    static let ringDuration = 1.0

    /// A card rising over the frame and an element opening into it: as long as a sheet or an app takes to open.
    static let stackDuration = 0.7
    static let expandDuration = 0.65

    /// How a light or dither film's opening control comes in: in its look's seam out of the ground alone, where
    /// satin cuts it in as Raycast's bar did. Cut in, bolt.new's prompt box and its blob of light had nothing
    /// joining them.
    static func arrival(on field: MotionField) -> Transition? {
        switch field.family {
        case .light: Transition(seam: .glow, duration: glowDuration)
        case .dither: Transition(seam: .dither, duration: ditherDuration)
        default: nil
        }
    }

    /// The camera's speed where the scene before ends: canvas pixels a second each way, and its zoom's
    /// log a second.
    nonisolated struct Velocity: Equatable, Sendable {
        var horizontal = 0.0
        var vertical = 0.0
        var zoom = 0.0
    }

    /// How long a carried-over speed takes to settle.
    static let carryTimeConstant = 0.45

    /// A whip leaves over the scene's last 0.15 s, half a frame's width, and arrives over 0.45 s from 0.8
    /// of one: speeds that meet at the cut (about ten widths a second), each sampled into motion blur.
    static let whipOut = (duration: 0.15, travel: 0.5)
    static let whipIn = (duration: 0.45, travel: 0.8)

    /// - Parameters:
    ///   - outgoingDuration: The scene before's length.
    ///   - hasText: Whether either scene shows text: a blur across the cut stays within 10 px on
    ///     text, 18 on surfaces.
    ///   - velocity: The camera's at the end of the scene before.
    ///   - zooms: How magnified each side's camera shows the canvas where they meet: a whip's travel is a
    ///     share of the frame, whatever the zoom.
    static func effect(
        of seam: MotionSeam, outgoingDuration: Double, canvas: CGSize, hasText: Bool, velocity: Velocity, zooms: (outgoing: Double, incoming: Double) = (1, 1)
    ) -> Effect {
        let unit = canvas.height / 1080
        let blur = (hasText ? 10 : 18) * unit
        var effect = Effect()
        func outgoing(_ property: MotionProperty, _ begin: Double, _ end: Double, last duration: Double, easing: MotionEasing) {
            let start = max(outgoingDuration - duration, 0)
            effect.outgoing[property, default: []].append(PropertyTrack(
                property, from: Keyframe(time: start, value: begin, easing: easing), to: Keyframe(time: outgoingDuration, value: end)
            ))
        }
        func incoming(_ property: MotionProperty, _ begin: Double, _ end: Double, over duration: Double, easing: MotionEasing) {
            effect.incoming[property, default: []].append(PropertyTrack(
                property, from: Keyframe(time: 0, value: begin, easing: easing), to: Keyframe(time: duration, value: end)
            ))
        }
        switch seam {
        case .cut:
            break
        case .zoomThrough:
            // 0.2 s out (1 → 1.2), 0.5 s in (0.75 → 1, out-expo)
            outgoing(.scale, 1, 1.2, last: 0.2, easing: .exit)
            outgoing(.blur, 0, blur, last: 0.2, easing: .exit)
            incoming(.scale, 0.75, 1, over: 0.5, easing: .enterFast)
            incoming(.blur, blur, 0, over: 0.3, easing: .enter)
        case .blurCut:
            outgoing(.blur, 0, blur, last: 0.15, easing: .exit)
            incoming(.blur, blur, 0, over: 0.3, easing: .enter)
        case .cutOnMotion:
            // The speed carried over, slowing exponentially: v·τ of travel
            let tau = carryTimeConstant
            let settle = 3 * tau
            let reach = tau * (1 - exp(-settle / tau))
            incoming(.positionX, 0, velocity.horizontal * reach, over: settle, easing: .settle(timeConstant: tau))
            incoming(.positionY, 0, velocity.vertical * reach, over: settle, easing: .settle(timeConstant: tau))
            incoming(.scale, 1, exp(velocity.zoom * reach), over: settle, easing: .settle(timeConstant: tau))
        case .whip:
            let width = canvas.width
            outgoing(.positionX, 0, whipOut.travel * width / zooms.outgoing, last: whipOut.duration, easing: .exit)
            incoming(.positionX, -whipIn.travel * width / zooms.incoming, 0, over: whipIn.duration, easing: .enterFast)
        case .push, .fade, .stack, .expand, .glow, .dither, .ring:
            effect.transition = Transition(seam: seam, duration: duration(of: seam))
        }
        return effect
    }

    /// How long a seam that draws both scenes at once takes.
    private static func duration(of seam: MotionSeam) -> Double {
        switch seam {
        case .stack: stackDuration
        case .expand: expandDuration
        case .glow: glowDuration
        case .dither: ditherDuration
        case .ring: ringDuration
        default: 0.5
        }
    }
}
