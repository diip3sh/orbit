//
//  EditorTheme.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The editor's look, after zeron.sh: a violet-black ground the desktop frosts through, text in
/// three tones (ink, dim, faint), hairlines instead of boxes, an off-white main button, and one
/// purple for the playhead and the selection.
enum EditorTheme {

    /// The ground, laid over the desktop at 80% like the app's shell. #06040a
    static let stage = Color(red: 0.024, green: 0.016, blue: 0.039)

    /// Under the timeline. #0c0913
    static let panel = Color(red: 0.047, green: 0.035, blue: 0.075)

    /// Text. #ece7f7
    static let ink = Color(red: 0.925, green: 0.906, blue: 0.969)

    /// Values, notes and the other text under the main one. #9c92b5
    static let dim = Color(red: 0.612, green: 0.573, blue: 0.71)

    /// Marks that only structure, like ruler ticks and section titles' chevrons. #5d5178
    static let faint = Color(red: 0.365, green: 0.318, blue: 0.471)

    /// Lines between areas and around pictures. #241c36
    static let hairline = Color(red: 0.141, green: 0.11, blue: 0.212)

    /// Lanes and quieter edges. #1a1428
    static let softHairline = Color(red: 0.102, green: 0.078, blue: 0.157)

    /// The playhead and the selection. Nothing else is purple. #8b5cf6
    static let accent = Color(red: 0.545, green: 0.361, blue: 0.965)

    /// The main button (Export, play) and the trim handles, with its hover and its text.
    /// #f7f4ee, #ddd6ea, #17141d
    static let primary = Color(red: 0.969, green: 0.957, blue: 0.933)
    static let primaryHover = Color(red: 0.867, green: 0.839, blue: 0.918)
    static let primaryInk = Color(red: 0.09, green: 0.078, blue: 0.114)

    // Space on a 4-point grid: inside a control, between a title and its control, between
    // controls, around panels, and around the stage and sheets
    static let tightSpacing: CGFloat = 4
    static let smallSpacing: CGFloat = 8
    static let mediumSpacing: CGFloat = 12
    static let spacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24

    /// Every state change, so the editor moves one way.
    static let motion = Animation.snappy(duration: 0.28)
}
