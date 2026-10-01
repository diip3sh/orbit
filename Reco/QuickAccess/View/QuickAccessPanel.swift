//
//  QuickAccessPanel.swift
//  Reco
//
//  Created by Diip3sh on 30.09.26.
//

import AppKit

/// The Quick Access card's panel, which takes the keyboard so ⌘C and ⌘S reach the card.
///
/// A borderless panel refuses key by default. This one takes it without activating the app, and
/// gives it up as soon as another window is clicked.
final class QuickAccessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
