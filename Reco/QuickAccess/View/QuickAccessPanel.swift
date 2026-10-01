//
//  QuickAccessPanel.swift
//  Reco
//
//  Created by Diip3sh on 30.09.26.
//

import AppKit

/// A borderless panel that takes the keyboard without activating the app: the Quick Access card's,
/// so ⌘C and ⌘S reach it, and the Record with AI Agent bar's, so typing does.
///
/// A borderless panel refuses key by default. This one gives it up as soon as another window is clicked.
final class QuickAccessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
