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

    private struct MotionEditor {
        let window: NSWindow
        let viewModel: MotionEditorViewModel
        let accessesOutputDirectory: Bool
    }

    private let settings: SettingsStore

    /// Runs what a web take's agent chat asks.
    private let agentRecording: AgentRecordingViewModel
    private var editors: [URL: Editor] = [:]
    private var recordings: Recordings?
    private var webRecording: WebRecording?
    private var motionEditors: [URL: MotionEditor] = [:]

    init(settings: SettingsStore, agentRecording: AgentRecordingViewModel) {
        self.settings = settings
        self.agentRecording = agentRecording
    }

    /// Opens the editor for a recording in the output folder, or brings its window forward.
    /// - Parameter conversation: The agent chat that made it, when a run just recorded it.
    func open(_ videoURL: URL, conversation: [AgentChatMessage] = []) {
        let videoURL = videoURL.standardizedFileURL
        if let window = editors[videoURL]?.window {
            activate(window)
            return
        }

        // Held while the window is open: the project autosaves next to the recording
        let accessesOutputDirectory = settings.startAccessingOutputDirectory()

        let viewModel = EditorViewModel(videoURL: videoURL)
        let chat = AgentChatViewModel(movie: videoURL, runner: agentRecording, conversation: conversation)
        let window = makeWindow(contained(editorController(viewModel, chat)), title: videoURL.deletingPathExtension().lastPathComponent, size: NSSize(width: 1280, height: 800))
        window.representedURL = videoURL
        window.contentMinSize = EditorView.minimumSize
        editors[videoURL] = Editor(window: window, viewModel: viewModel, accessesOutputDirectory: accessesOutputDirectory)

        // A regular app gets a Dock icon, ⌘-Tab and the main menu with Undo and Redo
        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    /// Opens a take an agent recorded, with its conversation: in the window of the take it changes,
    /// keeping that take's look, or in a new window. The window shows the take it has until the new
    /// one has loaded.
    func open(_ take: AgentRecordedTake) {
        let movie = take.movie.standardizedFileURL
        guard let replaced = take.replacing?.standardizedFileURL, let editor = editors[replaced], editors[movie] == nil else {
            open(movie, conversation: take.conversation)
            return
        }
        let viewModel = EditorViewModel(videoURL: movie, style: editor.viewModel.project)
        let chat = AgentChatViewModel(movie: movie, runner: agentRecording, conversation: take.conversation)
        Task {
            // Loaded first: the window would size itself to the loading placeholder
            await viewModel.load()
            guard let current = editors[replaced], current.window === editor.window,
                  let hostingController = editor.window.contentViewController?.children.first as? NSHostingController<EditorView> else {
                open(movie, conversation: take.conversation)
                return
            }
            hostingController.rootView = EditorView(viewModel: viewModel, chat: chat)
            editor.window.title = movie.deletingPathExtension().lastPathComponent
            editor.window.representedURL = movie
            editors[replaced] = nil
            // The folder's scope moves with the window
            editors[movie] = Editor(window: editor.window, viewModel: viewModel, accessesOutputDirectory: editor.accessesOutputDirectory)
            await editor.viewModel.close()
            activate(editor.window)
        }
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

    /// Shows the Web Recording window, or brings it forward, on `url` when given. Each render opens
    /// in the editor.
    func showWebRecording(at url: URL? = nil) {
        defer {
            if let url, let viewModel = webRecording?.viewModel {
                viewModel.address = url.absoluteString
                viewModel.commitAddress()
            }
        }
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

    /// Opens a motion bundle (spec 0011) in its own window, or brings its window forward.
    func openMotion(_ bundleURL: URL) {
        let bundleURL = bundleURL.standardizedFileURL
        if let window = motionEditors[bundleURL]?.window {
            activate(window)
            return
        }

        let accessesOutputDirectory = settings.startAccessingOutputDirectory()
        let viewModel = MotionEditorViewModel(bundleURL: bundleURL)
        let hostingController = NSHostingController(rootView: MotionEditorView(viewModel: viewModel))
        hostingController.sizingOptions = []
        hostingController.sceneBridgingOptions = [.toolbars]
        let window = makeWindow(contained(hostingController), title: bundleURL.deletingPathExtension().lastPathComponent, size: NSSize(width: 1280, height: 800))
        window.representedURL = bundleURL
        motionEditors[bundleURL] = MotionEditor(window: window, viewModel: viewModel, accessesOutputDirectory: accessesOutputDirectory)

        NSApp.setActivationPolicy(.regular)
        activate(window)
    }

    private func editorController(_ viewModel: EditorViewModel, _ chat: AgentChatViewModel) -> NSHostingController<EditorView> {
        let hostingController = NSHostingController(rootView: EditorView(viewModel: viewModel, chat: chat))
        // No sizes from the content: the window holds the minimum itself (`open`)
        hostingController.sizingOptions = []
        // The export and inspector buttons are SwiftUI toolbar items
        hostingController.sceneBridgingOptions = [.toolbars]
        return hostingController
    }

    /// `controller` filling a plain view controller. As a window's own content, a hosting view
    /// resizes the window to its smallest size once the recording has loaded
    /// (`NSHostingView.updateAnimatedWindowSize`); a level down it leaves the window alone.
    private func contained(_ controller: NSViewController) -> NSViewController {
        let container = NSViewController()
        container.view = NSView()
        container.addChild(controller)
        let (view, content) = (container.view, controller.view)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        return container
    }

    /// A centred window in the editor's look: the content running under a transparent title bar and toolbar.
    private func makeWindow(_ contentViewController: NSViewController, title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(contentViewController: contentViewController)
        window.title = title
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.backgroundColor = .windowBackgroundColor
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
        if let motion = motionEditors.values.first(where: { $0.window === window }) {
            return motion.viewModel.undoManager
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
        } else if let (bundleURL, motion) = motionEditors.first(where: { $0.value.window === window }).map({ ($0.key, $0.value) }) {
            motionEditors[bundleURL] = nil
            let settings = settings
            Task {
                // Saving needs the folder, so its scope is released only afterwards
                await motion.viewModel.close()
                if motion.accessesOutputDirectory {
                    settings.stopAccessingOutputDirectory()
                }
            }
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
        if editors.isEmpty, motionEditors.isEmpty, recordings == nil, webRecording == nil {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
