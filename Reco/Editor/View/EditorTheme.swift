//
//  EditorTheme.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Reco's look: surfaces one step apart, text in three tones (ink, dim, faint), hairlines instead of boxes, and one
/// accent for the one action and what is chosen. Every colour is a colour set in `Assets.xcassets/Theme`, written from
/// `theme/theme.tokens.json`: dark from Linear's tokens with acid lime, light from Default's (snow, bone, chalk) with
/// iris, and an Increase Contrast variant of each, so the app follows the user's appearance. Ink, dim and the accent
/// meet WCAG AA (4.5:1 for text, 3:1 for faint marks and the accent) on every surface in all four variants
/// (`ThemeContrastTests`).
enum EditorTheme {

    /// The window's ground (void `#08090a`).
    static let stage = Color(.stage)

    /// Under the timeline (carbon `#0f1011`).
    static let panel = Color(.panel)

    /// Cards and floating panels: the capture toolbar, the Quick Access card, the popover (carbon `#0f1011`).
    static let surface = Color(.surface)

    /// What floats over a surface: tooltips, menus, the source picker (obsidian `#161718`).
    static let raised = Color(.raised)

    /// Controls' own fill: secondary buttons, tracks, chosen tiles (slate `#23252a`).
    static let control = Color(.control)

    /// Text (bone `#e5e5e6`).
    static let ink = Color(.ink)

    /// Values, notes and the other text under the main one (fog `#8a8f98`).
    static let dim = Color(.dim)

    /// Marks that only structure, like ruler ticks and section titles' chevrons (ash, a step lighter: `#72767d`).
    static let faint = Color(.faint)

    /// Lines between areas and around pictures (graphite `#23252a`).
    static let hairline = Color(.hairline)

    /// Lanes and quieter edges (obsidian `#161718`).
    static let softHairline = Color(.softHairline)

    /// Lines, text and marks in the accent: the playhead, the selection, a chosen tab. Acid lime `#e4f222` in
    /// dark, iris `#314ef0` in light.
    static let accent = Color.accentColor

    /// The accent as a fill, with `onAccent` on it: void on lime in dark, white on iris in light.
    static let accentFill = Color(.accentFill)
    static let onAccent = Color(.onAccent)

    /// The main button (Export, play), with its hover and its text.
    static let primary = accentFill
    static let primaryHover = accentFill.opacity(0.85)
    static let primaryInk = onAccent

    // Space on a 4-point grid: inside a control, between a title and its control, between
    // controls, around panels, and around the stage and sheets
    static let tightSpacing: CGFloat = 4
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 12
    static let spacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24

    // Corner radii: buttons and fields (md), cards and floating panels (xl), large panels (2xl)
    static let smallRadius: CGFloat = 6
    static let radius: CGFloat = 12
    static let largeRadius: CGFloat = 16

    /// Every state change, so the app moves one way: critically damped, no overshoot.
    static let motion = Animation.spring(response: 0.35, dampingFraction: 1)

    /// Hover and release: fast enough to feel instant, still continuous.
    static let quickMotion = Animation.spring(response: 0.15, dampingFraction: 1)

    /// Only after a flick: the gesture carried momentum, so a little bounce reads as physical.
    static let momentumMotion = Animation.spring(response: 0.35, dampingFraction: 0.8)

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
