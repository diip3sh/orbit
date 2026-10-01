//
//  EditorWindowManager.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import AppKit
import SwiftUI

/// Opens one editor window per recording, the Recordings window and the Web Recording window, and
/// keeps the app in the Dock while any is open.
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

    private struct Recordings {
        let window: NSWindow
        let viewModel: RecordingsViewModel
        let accessesOutputDirectory: Bool
    }

    private struct WebRecording {
        let window: NSWindow
        let viewModel: WebRecordingViewModel
    }

    private let settings: SettingsStore
    private var editors: [URL: Editor] = [:]
    private var recordings: Recordings?
    private var webRecording: WebRecording?

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
        let window = makeWindow(hostingController, title: videoURL.deletingPathExtension().lastPathComponent, size: NSSize(width: 1280, height: 800))
        window.representedURL = videoURL
        editors[videoURL] = Editor(window: window, viewModel: viewModel, accessesOutputDirectory: accessesOutputDirectory)

        // A regular app gets a Dock icon, ⌘-Tab and the main menu with Undo and Redo
        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    /// Shows the output folder's recordings, or brings their window forward.
    func showRecordings() {
        if let recordings {
            activate(recordings.window)
            return
        }

        // Held while the window is open: it lists the folder and reads the recordings' pictures
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()
        let viewModel = RecordingsViewModel(folder: settings.outputDirectory) { [weak self] url in
            self?.open(url)
        }
        let hostingController = NSHostingController(rootView: RecordingsView(viewModel: viewModel))
        hostingController.sizingOptions = .minSize
        let window = makeWindow(hostingController, title: "Recordings", size: NSSize(width: 860, height: 600))
        recordings = Recordings(window: window, viewModel: viewModel, accessesOutputDirectory: accessesOutputDirectory)

        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    /// Shows the Web Recording window, or brings it forward. Each render opens in the editor.
    func showWebRecording() {
        if let webRecording {
            activate(webRecording.window)
            return
        }

        let viewModel = WebRecordingViewModel(settings: settings) { [weak self] url in
            self?.open(url)
        }
        let hostingController = NSHostingController(rootView: WebRecordingView(viewModel: viewModel))
        hostingController.sizingOptions = .minSize
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = makeWindow(hostingController, title: "Web Recording", size: NSSize(width: 1280, height: 860))
        webRecording = WebRecording(window: window, viewModel: viewModel)

        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    /// A centred window in the editor's look: always dark, the content running under a transparent
    /// title bar and toolbar.
    private func makeWindow(_ contentViewController: NSViewController, title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(contentViewController: contentViewController)
        window.title = title
        window.appearance = NSAppearance(named: .darkAqua)
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = NSColor(EditorTheme.stage)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(size)
        window.center()
        return window
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
        if let webRecording, window === webRecording.window {
            return webRecording.viewModel.undoManager
        }
        return editor(for: window)?.editor.viewModel.undoManager
    }

    /// The list is read whenever it comes forward, so recordings saved meanwhile show.
    func windowDidBecomeKey(_ notification: Notification) {
        guard let recordings, notification.object as? NSWindow === recordings.window else { return }
        Task {
            await recordings.viewModel.reload()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if let recordings, window === recordings.window {
            self.recordings = nil
            if recordings.accessesOutputDirectory {
                settings.stopAccessingOutputDirectory()
            }
        } else if let webRecording, window === webRecording.window {
            self.webRecording = nil
            webRecording.viewModel.close()
        } else if let (videoURL, editor) = editor(for: window) {
            editors[videoURL] = nil
            let settings = settings
            Task {
                // Saving needs the folder, so its scope is released only afterwards
                await editor.viewModel.close()
                if editor.accessesOutputDirectory {
                    settings.stopAccessingOutputDirectory()
                }
            }
        }
        if editors.isEmpty, recordings == nil, webRecording == nil {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
