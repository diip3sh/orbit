//
//  EditorTheme.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The editor's look: always dark, neutral greys and one signal color, so the recording is the
/// brightest thing in the window.
enum EditorTheme {

    /// Behind the preview.
    static let stage = Color(red: 0.055, green: 0.055, blue: 0.063)

    /// Under the timeline and the inspector.
    static let panel = Color(red: 0.086, green: 0.086, blue: 0.094)

    /// Thin lines between areas and around pictures.
    static let hairline = Color.white.opacity(0.08)

    /// The signal color: the playhead, the selection and Export. Nothing else is colored.
    static let accent = Color(red: 1, green: 0.373, blue: 0.122)

    /// The edges of the kept parts and their handles.
    static let trim = Color.white.opacity(0.92)

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
