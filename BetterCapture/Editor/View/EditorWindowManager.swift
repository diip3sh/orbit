//
//  EditorWindowManager.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import AppKit
import SwiftUI

/// Opens one editor window per recording, and keeps the app in the Dock while any is open.
///
/// The app is a menu bar app (`LSUIElement`), and its entry points - notifications, URLs, the menu
/// bar - have no SwiftUI window environment, so editor windows are AppKit windows hosting SwiftUI.
@MainActor
final class EditorWindowManager: NSObject {

    private struct Editor {
        let window: NSWindow
        let viewModel: EditorViewModel

        /// Whether the output folder's security scope was started for this window.
        let accessesOutputDirectory: Bool
    }

    private let settings: SettingsStore
    private var editors: [URL: Editor] = [:]

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Opens the editor for a recording in the output folder, or brings its window forward.
    func open(_ videoURL: URL) {
        let videoURL = videoURL.standardizedFileURL
        if let window = editors[videoURL]?.window {
            activate(window)
            return
        }

        // Held while the window is open: the project autosaves next to the recording
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()

        let viewModel = EditorViewModel(videoURL: videoURL)
        let hostingController = NSHostingController(rootView: EditorView(viewModel: viewModel))
        // Only the minimum size, so the window doesn't resize itself to fit the loading placeholder
        hostingController.sizingOptions = .minSize
        // The export and inspector buttons are SwiftUI toolbar items
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = NSWindow(contentViewController: hostingController)
        window.title = videoURL.deletingPathExtension().lastPathComponent
        window.representedURL = videoURL
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 1100, height: 720))
        window.center()
        editors[videoURL] = Editor(window: window, viewModel: viewModel, accessesOutputDirectory: accessesOutputDirectory)

        // A regular app gets a Dock icon, ⌘-Tab and the main menu with Undo and Redo
        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    private func activate(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func editor(for window: NSWindow) -> (videoURL: URL, editor: Editor)? {
        editors.first { $0.value.window === window }.map { ($0.key, $0.value) }
    }
}

// MARK: - NSWindowDelegate

extension EditorWindowManager: NSWindowDelegate {

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        editor(for: window)?.editor.viewModel.undoManager
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, let (videoURL, editor) = editor(for: window) else { return }
        editors[videoURL] = nil
        if editors.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        }

        let settings = settings
        Task {
            // Saving needs the folder, so its scope is released only afterwards
            await editor.viewModel.close()
            if editor.accessesOutputDirectory {
                settings.stopAccessingOutputDirectory()
            }
        }
    }
}
