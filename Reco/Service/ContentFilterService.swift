//
//  ContentFilterService.swift
//  Reco
//
//  Created by Joshua Sattler on 29.01.26.
//

import Foundation
@preconcurrency import ScreenCaptureKit
import OSLog
import CoreGraphics
import AVFoundation

/// Service responsible for applying content filter settings (wallpaper, dock, menu bar)
@MainActor
final class ContentFilterService {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "ContentFilterService")

    /// Checks if screen recording permission has been granted
    /// - Returns: true if permission is granted
    func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Requests screen recording permission from the user
    /// - Returns: true if permission was granted (or was already granted)
    @discardableResult
    func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Checks if microphone permission has been granted
    /// - Returns: true if permission is granted
    func hasMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Requests microphone permission from the user
    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Checks whether the display targeted by a filter is still connected
    ///
    /// A display picked from the content picker is captured by its `displayID`. Disconnecting
    /// the display leaves the filter intact but makes it produce no frames, so it has to be
    /// validated against the currently connected displays before capture starts. Window and
    /// application filters are not bound to a display and always pass.
    /// - Parameter filter: The filter to validate
    /// - Returns: true if the filter can still be captured
    func isSelectedDisplayConnected(_ filter: SCContentFilter) async -> Bool {
        guard filter.style == .display,
              let displayID = filter.includedDisplays.first?.displayID else {
            return true
        }

        guard let content = try? await SCShareableContent.current else {
            // Nothing to validate against - let the capture attempt surface the real failure
            logger.warning("Could not read shareable content, skipping display validation")
            return true
        }

        let isConnected = content.displays.contains { $0.displayID == displayID }

        if !isConnected {
            logger.warning("Selected display \(displayID) is no longer connected")
        }

        return isConnected
    }

    /// Applies user settings to a content filter
    ///
    /// The filter is rebuilt in place for its own style. A filter is never widened: if any
    /// assumption about its shape does not hold, the picker's filter is returned untouched
    /// rather than replaced by something that captures more than the user selected.
    /// - Parameters:
    ///   - filter: The original filter from the content picker
    ///   - settings: User settings for content visibility
    /// - Returns: A modified filter with settings applied
    func applySettings(to filter: SCContentFilter, settings: SettingsStore) async throws -> SCContentFilter {
        // Menu bar can be set directly on any filter
        filter.includeMenuBar = settings.showMenuBar

        let captureStyle = CaptureFilterStyle(filter)

        logger.info("""
            Filter shape - captures: \(String(describing: captureStyle)), \
            reported style: \(filter.style.rawValue), \
            displays: \(filter.includedDisplays.count), \
            applications: \(filter.includedApplications.count), \
            windows: \(filter.includedWindows.count)
            """)

        switch captureStyle {
        case .display:
            return try await applyToDisplayFilter(filter, settings: settings)
        case .application:
            return try await applyToApplicationFilter(filter, settings: settings)
        case .window, .unknown:
            // Nothing here can be rebuilt without widening the capture
            logger.info("Filter needs no rebuild, returning with menu bar setting only")
            return filter
        }
    }

    // MARK: - Display Capture

    /// Rebuilds a display filter so hidden surfaces are excluded window by window
    private func applyToDisplayFilter(_ filter: SCContentFilter, settings: SettingsStore) async throws -> SCContentFilter {
        let visibility = ContentVisibility(settings: settings)

        guard let display = filter.includedDisplays.first else {
            logger.warning("Display filter without a display, returning picker filter as-is")
            return filter
        }

        guard ContentFilterRules.requiresRebuild(visibility: visibility) else {
            logger.info("No exclusions needed, returning original filter")
            return filter
        }

        // Check for screen recording permission before accessing SCShareableContent
        guard hasScreenRecordingPermission() else {
            logger.warning("Screen recording permission not granted, skipping window exclusions")
            return filter
        }

        let onScreenWindows = try await onScreenWindows()
        let excludedIDs = Set(ContentFilterRules.excludedWindowIDs(
            from: onScreenWindows.map(CapturableWindow.init),
            visibility: visibility
        ))
        let excludedWindows = onScreenWindows.filter { excludedIDs.contains($0.windowID) }

        logger.info("Excluding \(excludedWindows.count) windows from capture")

        let newFilter = SCContentFilter(display: display, excludingWindows: excludedWindows)
        newFilter.includeMenuBar = settings.showMenuBar

        return newFilter
    }

    // MARK: - Application Capture

    /// Composites wallpaper and Dock behind an application capture
    ///
    /// ScreenCaptureKit renders an application filter on black unless the Dock application —
    /// which owns both the wallpaper and the Dock itself — is part of the capture. The two
    /// surfaces are separated again through `exceptingWindows`.
    private func applyToApplicationFilter(_ filter: SCContentFilter, settings: SettingsStore) async throws -> SCContentFilter {
        let visibility = ContentVisibility(settings: settings)

        // App on black. Nothing to composite, so leave the picker's filter alone.
        guard ContentFilterRules.includesDockApplication(visibility: visibility) else {
            logger.info("Wallpaper and dock both hidden, keeping application filter as-is")
            return filter
        }

        guard let display = filter.includedDisplays.first,
              !filter.includedApplications.isEmpty,
              hasScreenRecordingPermission() else {
            logger.warning("Cannot rebuild application filter, using picker filter as-is")
            return filter
        }

        let content = try await SCShareableContent.current
        let onScreenWindows = content.windows.filter(\.isOnScreen)

        guard let dockApp = content.applications.first(where: { $0.bundleIdentifier == ContentFilterRules.dockBundleID }) else {
            logger.warning("Dock application not found, using picker filter as-is")
            return filter
        }

        let exceptionIDs = Set(ContentFilterRules.dockExceptionWindowIDs(
            from: onScreenWindows.map(CapturableWindow.init),
            visibility: visibility
        ))
        let exceptions = onScreenWindows.filter { exceptionIDs.contains($0.windowID) }

        logger.info("Compositing application capture with \(exceptions.count) dock windows excepted")

        // Keep the application restriction rather than snapshotting windows, so windows the
        // app opens mid-recording are captured too.
        let newFilter = SCContentFilter(
            display: display,
            including: filter.includedApplications + [dockApp],
            exceptingWindows: exceptions
        )
        newFilter.includeMenuBar = settings.showMenuBar

        return newFilter
    }

    // MARK: - Helpers

    /// The currently visible windows across all displays
    private func onScreenWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.current
        return content.windows.filter(\.isOnScreen)
    }
}

// MARK: - CapturableWindow Bridging

private extension CapturableWindow {

    /// Reduces a ScreenCaptureKit window to the properties the filter rules need
    init(_ window: SCWindow) {
        self.init(
            id: window.windowID,
            bundleID: window.owningApplication?.bundleIdentifier ?? "",
            title: window.title ?? ""
        )
    }
}
