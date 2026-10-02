//
//  EditorTheme.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The editor's look in the system's colors, so it follows the user's appearance (light or dark) and
/// accent color: text in three tones (ink, dim, faint), hairlines instead of boxes, a label-colored main
/// button, and the accent for the playhead and the selection.
enum EditorTheme {

    /// The ground, laid over the desktop at 80%.
    static let stage = Color(nsColor: .windowBackgroundColor)

    /// The timeline's tray and the chat's quiet surfaces: a step off the ground that lets it through.
    static let tray = Color.primary.opacity(0.05)
    static let trayShape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    /// Zoom blocks on the timeline.
    static let panel = Color(nsColor: .underPageBackgroundColor)

    /// Text.
    static let ink = Color(nsColor: .labelColor)

    /// Values, notes and the other text under the main one.
    static let dim = Color(nsColor: .secondaryLabelColor)

    /// Marks that only structure, like ruler ticks and section titles' chevrons.
    static let faint = Color(nsColor: .tertiaryLabelColor)

    /// Lines between areas and around pictures.
    static let hairline = Color(nsColor: .separatorColor)

    /// Lanes and quieter edges.
    static let softHairline = Color(nsColor: .quaternarySystemFill)

    /// The playhead and the selection, the only color in the chrome: a warm orange, whatever the
    /// user's accent color. Controls are ink.
    static let accent = Color(red: 1, green: 0.45, blue: 0.2)

    /// The main button (Export, play) and the trim handles, with its hover and its text: the label
    /// color, so dark on light and light on dark.
    static let primary = Color(nsColor: .labelColor)
    static let primaryHover = Color(nsColor: .labelColor).opacity(0.85)
    static let primaryInk = Color(nsColor: .windowBackgroundColor)

    // Space on a 4-point grid: inside a control, between a title and its control, between
    // controls, around panels, and around the stage and sheets
    static let tightSpacing: CGFloat = 4
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 12
    static let spacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24

    /// Every state change, so the app moves one way: critically damped, no overshoot.
    static let motion = Animation.spring(response: 0.35, dampingFraction: 1)

    /// Hover and release: fast enough to feel instant, still continuous.
    static let quickMotion = Animation.spring(response: 0.15, dampingFraction: 1)

    /// Only after a flick: the gesture carried momentum, so a little bounce reads as physical.
    static let momentumMotion = Animation.spring(response: 0.35, dampingFraction: 0.8)

    /// A thumb or a knob sliding to where it was sent (switches, tabs, a slider's knob let go): quick,
    /// with the slightest overshoot, as system switches settle.
    static let slideMotion = Animation.spring(response: 0.3, dampingFraction: 0.78)

    /// Reduce Motion's stand-in for movement: a short cross-fade.
    static let fadeMotion = Animation.easeOut(duration: 0.15)

    /// The spring a drag hands off to when released, carrying the release speed so the motion
    /// continues without a seam. `velocity` in points per second, `distance` the way left to go.
    static func release(velocity: Double, distance: Double) -> Animation {
        .interpolatingSpring(
            SwiftUI.Spring(response: 0.35, dampingRatio: 1),
            initialVelocity: GesturePhysics.relativeVelocity(velocity, from: 0, to: distance)
        )
    }
}
