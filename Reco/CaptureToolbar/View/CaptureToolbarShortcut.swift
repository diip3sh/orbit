//
//  CaptureToolbarShortcut.swift
//  Reco
//

import SwiftUI

/// A key the capture toolbar answers while it has key (idle only, so typing never leaves the app being
/// recorded), and how its tooltip writes it. Plain keys, as in the system's Screenshot toolbar: the bar
/// is the only thing taking keys while it is up.
struct CaptureToolbarShortcut {
    let key: KeyEquivalent
    var modifiers: EventModifiers = []
    let symbol: String

    static let close = Self(key: .escape, symbol: "esc")
    static let action = Self(key: .return, symbol: "↩")
    static let settings = Self(key: ",", modifiers: .command, symbol: "⌘,")
    static let systemAudio = Self(key: "a", symbol: "A")
    static let microphone = Self(key: "m", symbol: "M")
    static let camera = Self(key: "c", symbol: "C")

    /// 1, 2 and 3 for screen, window and area, in either toolbar
    static func mode(_ mode: CaptureToolbarMode) -> Self {
        switch mode {
        case .captureScreen, .recordScreen: Self(key: "1", symbol: "1")
        case .captureWindow, .recordWindow: Self(key: "2", symbol: "2")
        case .captureArea, .recordArea: Self(key: "3", symbol: "3")
        }
    }
}
