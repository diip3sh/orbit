//
//  KeyboardShortcutNames.swift
//  Reco
//
//  Created by Joshua Sattler on 28.03.26.
//

import AppKit
import KeyboardShortcuts

// Defaults ⌘1–⌘7 in the menu's order of use: screenshots, then choosing and recording. Global
// shortcuts win over apps, so these take ⌘1–⌘7 from every app (a browser's tab switching) until changed.
extension KeyboardShortcuts.Name {
    static let captureArea = Self("captureArea", initial: .init(.one, modifiers: .command))
    static let captureWindow = Self("captureWindow", initial: .init(.two, modifiers: .command))
    static let captureScreen = Self("captureScreen", initial: .init(.three, modifiers: .command))
    static let selectContent = Self("selectContent", initial: .init(.four, modifiers: .command))
    static let selectArea = Self("selectArea", initial: .init(.five, modifiers: .command))
    static let toggleRecording = Self("toggleRecording", initial: .init(.six, modifiers: .command))
    static let pauseRecording = Self("pauseRecording", initial: .init(.seven, modifiers: .command))
    static let recordWithAgent = Self("recordWithAgent")
}
