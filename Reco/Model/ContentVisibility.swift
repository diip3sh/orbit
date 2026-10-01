//
//  ContentVisibility.swift
//  Reco
//
//  Created by Joshua Sattler on 30.08.26.
//

import Foundation

/// The user's content filter preferences, decoupled from ``SettingsStore`` so the
/// rules in ``ContentFilterRules`` can be tested without `UserDefaults`.
struct ContentVisibility: Equatable, Sendable {

    /// Whether the desktop wallpaper is part of the capture.
    let showWallpaper: Bool

    /// Whether the Dock is part of the capture.
    let showDock: Bool

    /// Whether Reco's own windows are part of the capture.
    let showReco: Bool

    /// The bundle identifier of this app, used to recognise its own windows.
    let ownBundleID: String
}

extension ContentVisibility {

    /// Reads the visibility preferences from the settings store.
    @MainActor
    init(settings: SettingsStore) {
        self.init(
            showWallpaper: settings.showWallpaper,
            showDock: settings.showDock,
            showReco: settings.showReco,
            ownBundleID: Bundle.main.bundleIdentifier ?? ""
        )
    }
}
