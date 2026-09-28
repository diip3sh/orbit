//
//  AppDelegate.swift
//  BetterCapture
//
//  Created by Joshua Sattler on 30.08.26.
//

import AppKit
import KeyboardShortcuts
import OSLog

/// Owns the recorder, registers the global keyboard shortcuts, and handles
/// `bettercapture://` URLs.
///
/// None of this can live on the `MenuBarExtra` scene. SwiftUI only routes external
/// events such as URLs to window-presenting scenes, and the menu bar content is not built
/// until the user first opens the popover, so neither `onOpenURL` nor a `.task` there ever
/// runs at launch. `NSApplicationDelegate` is active from launch onwards, which is why the
/// recorder is owned here: it has to be reachable without the popover ever being opened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let viewModel = RecorderViewModel()

    private lazy var editorWindows = EditorWindowManager(settings: viewModel.settings)
    private lazy var quickAccess = QuickAccessController(settings: viewModel.settings)

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BetterCapture", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerKeyboardShortcuts()
        viewModel.notificationService.editRecording = editorWindows.open
    }

    /// Opens the last recording saved since launch in the editor.
    func editLastRecording() {
        guard let url = viewModel.lastRecordingURL else {
            logger.info("No recording to edit yet")
            return
        }
        editorWindows.open(url)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "bettercapture" {
            handle(url)
        }
    }

    // MARK: - Keyboard Shortcuts

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [viewModel] in
            Task { @MainActor in
                await viewModel.toggleRecording()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .pauseRecording) { [viewModel] in
            Task { @MainActor in
                viewModel.togglePause()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .selectContent) { [viewModel] in
            Task { @MainActor in
                viewModel.presentPicker()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .selectArea) { [viewModel] in
            Task { @MainActor in
                await viewModel.presentAreaSelection()
            }
        }

        logger.info("Registered global keyboard shortcuts")
    }

    // MARK: - URL Scheme

    private func handle(_ url: URL) {
        logger.info("Handling URL: \(url.absoluteString)")

        switch url.host {
        case "toggle", "toggle-copy":
            let copyToClipboard = url.host == "toggle-copy"
            Task {
                if viewModel.isRecording {
                    await viewModel.stopRecording(copyToClipboard: copyToClipboard)
                } else {
                    // Starts right away when content is already selected, without the countdown so automation stays precise
                    await viewModel.toggleRecording(countdown: false)
                }
            }
        case "pause":
            viewModel.togglePause()
        case "edit-last":
            editLastRecording()
        case "open-recordings":
            let settings = viewModel.settings
            let didStart = settings.startAccessingOutputDirectory()
            defer {
                if didStart {
                    settings.stopAccessingOutputDirectory()
                }
            }
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.outputDirectory.path)
#if DEBUG
        case "debug-quick-access":
            showNewestPNGInQuickAccess()
#endif
        default:
            logger.warning("Unhandled URL host: \(url.host ?? "nil")")
        }
    }
}

#if DEBUG
extension AppDelegate {

    /// Shows the newest PNG in the output folder: `open -g -a <app> "bettercapture://debug-quick-access"`
    func showNewestPNGInQuickAccess() {
        let settings = viewModel.settings
        let didStart = settings.startAccessingOutputDirectory()
        defer {
            if didStart {
                settings.stopAccessingOutputDirectory()
            }
        }

        let pngs = (try? FileManager.default.contentsOfDirectory(
            at: settings.outputDirectory, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let newest = pngs
            .filter { $0.pathExtension.lowercased() == "png" }
            .max { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate < rhsDate
            }

        guard let newest else {
            logger.info("No PNG in the output folder")
            return
        }
        quickAccess.show(fileURL: newest)
    }
}
#endif
