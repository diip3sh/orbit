//
//  ContentFilterRules.swift
//  Reco
//
//  Created by Joshua Sattler on 30.08.26.
//

import CoreGraphics
import Foundation

/// Decides which windows a content filter has to leave out to honour the user's
/// visibility preferences.
///
/// The rules are pure so they can be unit tested: building an `SCContentFilter` requires
/// screen recording permission, which is not available in a test process.
enum ContentFilterRules {

    /// The bundle identifier of the process owning both the wallpaper and the Dock.
    static let dockBundleID = "com.apple.dock"

    /// The title prefix macOS gives the windows that draw the desktop wallpaper.
    private static let wallpaperTitlePrefix = "Wallpaper-"

    /// A substring identifying the macOS 26 layer rendered behind the wallpaper.
    ///
    /// It is not reliably owned by the Dock, so it is matched by title alone.
    private static let backstopTitleFragment = "Backstop"

    // MARK: - Display Capture

    /// Whether a display capture needs its filter rebuilt at all.
    ///
    /// Rebuilding costs a `SCShareableContent` query, so a capture that hides nothing keeps
    /// the filter the content picker produced.
    static func requiresRebuild(visibility: ContentVisibility) -> Bool {
        !(visibility.showWallpaper && visibility.showDock && visibility.showReco)
    }

    /// Windows to exclude from a display capture.
    /// - Parameters:
    ///   - windows: The on-screen windows to classify.
    ///   - visibility: The user's visibility preferences.
    /// - Returns: The identifiers of the windows to leave out of the capture.
    static func excludedWindowIDs(
        from windows: [CapturableWindow],
        visibility: ContentVisibility
    ) -> [CGWindowID] {
        windows.filter { window in
            if !visibility.showWallpaper && isBackstop(window) { return true }

            if !visibility.showReco && isOwnWindow(window, visibility: visibility) { return true }

            return isHiddenDockOwnedWindow(window, visibility: visibility)
        }
        .map(\.id)
    }

    // MARK: - Application Capture

    /// Whether the Dock application has to be added to an application capture so the
    /// wallpaper and/or the Dock render behind the captured app.
    ///
    /// ScreenCaptureKit draws an application capture on black unless the process owning the
    /// desktop is part of the filter. Requesting neither surface therefore means requesting
    /// the app on black, and the Dock application stays out.
    static func includesDockApplication(visibility: ContentVisibility) -> Bool {
        visibility.showWallpaper || visibility.showDock
    }

    /// Dock-owned windows to except from an application capture.
    ///
    /// The Dock application owns both the wallpaper and the Dock itself, so excepting
    /// individual windows is the only way to show one without the other.
    /// - Parameters:
    ///   - windows: The on-screen windows to classify.
    ///   - visibility: The user's visibility preferences.
    /// - Returns: The identifiers of the windows to except, empty when the Dock application
    ///   is not part of the capture in the first place.
    static func dockExceptionWindowIDs(
        from windows: [CapturableWindow],
        visibility: ContentVisibility
    ) -> [CGWindowID] {
        guard includesDockApplication(visibility: visibility) else { return [] }

        return windows.filter { window in
            if !visibility.showWallpaper && isBackstop(window) { return true }
            return isHiddenDockOwnedWindow(window, visibility: visibility)
        }
        .map(\.id)
    }

    // MARK: - Classification

    private static func isBackstop(_ window: CapturableWindow) -> Bool {
        window.title.contains(backstopTitleFragment)
    }

    private static func isWallpaper(_ window: CapturableWindow) -> Bool {
        window.title.hasPrefix(wallpaperTitlePrefix)
    }

    /// Whether a window belongs to Reco itself.
    private static func isOwnWindow(_ window: CapturableWindow, visibility: ContentVisibility) -> Bool {
        !visibility.ownBundleID.isEmpty && window.bundleID == visibility.ownBundleID
    }

    /// Whether a Dock-owned window is hidden by the current preferences.
    private static func isHiddenDockOwnedWindow(
        _ window: CapturableWindow,
        visibility: ContentVisibility
    ) -> Bool {
        guard window.bundleID == dockBundleID else { return false }
        return isWallpaper(window) ? !visibility.showWallpaper : !visibility.showDock
    }
}
