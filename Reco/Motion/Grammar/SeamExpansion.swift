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

        /// How far it has gone at `time` into the next scene, eased.
        func progress(at time: Double) -> Double {
            switch seam {
            case .push: MotionEasing.move.progress(time / duration, duration: duration)
            default: min(max(time / duration, 0), 1)
            }
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

    /// - Parameters:
    ///   - outgoingDuration: The scene before's length.
    ///   - hasText: Whether either scene shows text: a blur across the cut stays within 10 px on
    ///     text, 18 on surfaces.
    ///   - velocity: The camera's at the end of the scene before.
    static func effect(of seam: MotionSeam, outgoingDuration: Double, canvas: CGSize, hasText: Bool, velocity: Velocity) -> Effect {
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
        case .push:
            effect.transition = Transition(seam: .push, duration: 0.5)
        case .fade:
            effect.transition = Transition(seam: .fade, duration: 0.5)
        }
        return effect
    }
}
