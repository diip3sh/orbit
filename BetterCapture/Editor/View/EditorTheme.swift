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

    /// The signal color: the playhead, the selection and the main button.
    static let accent = Color(red: 1, green: 0.373, blue: 0.122)

    /// The edges of the kept parts and their handles.
    static let trim = Color.white.opacity(0.92)

    static let clicks = Color(red: 1, green: 0.76, blue: 0.28)
    static let keys = Color(red: 0.31, green: 0.82, blue: 0.77)
    static let zoom = Color(red: 0.55, green: 0.47, blue: 1)

    /// Every state change, so the editor moves one way.
    static let motion = Animation.snappy(duration: 0.28)
}
