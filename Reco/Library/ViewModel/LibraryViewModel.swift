//
//  LibraryViewModel.swift
//  Reco
//

import AppKit
import OSLog

/// The Library window's state and intents (spec 0010): what Reco made, by section and search, with
/// opening, revealing, copying and trashing, and the ways to make something new.
@MainActor
@Observable
final class LibraryViewModel {

    /// What the window can start, provided by `AppDelegate`.
    struct Actions {
        var captureArea: () -> Void = {}
        var captureWindow: () -> Void = {}
        var captureScreen: () -> Void = {}
        var recordArea: () -> Void = {}
        var recordWindowOrDisplay: () -> Void = {}
        var newWebRecording: () -> Void = {}
        var recordWithAgent: () -> Void = {}
    }

    var section = LibrarySection.all
    var search = ""

    /// Newest first, or `nil` until the folders have been read.
    private(set) var items: [LibraryItem]?

    /// The items' pictures, loaded as their tiles appear.
    private(set) var thumbnails: [URL: CGImage] = [:]

    /// Why the folders couldn't be read, or an item couldn't be trashed.
    var error: String?

    let actions: Actions

    /// A tile's picture at most, in pixels: 16:10 at twice a wide tile's width on screen (320 pt).
    static let thumbnailSize = CGSize(width: 640, height: 400)

    @ObservationIgnored private let folders: () -> LibraryFolders
    @ObservationIgnored private let openMovie: (URL) -> Void
    @ObservationIgnored private let openFile: (URL) -> Void
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let trashItem: (LibraryItem) async throws -> Void
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "LibraryViewModel")

    /// - Parameters:
    ///   - folders: Where recordings and screenshots are saved, and the screenshot history, read on every
    ///     reload since Settings can change them.
    ///   - openMovie: Opens a recording in the editor.
    ///   - openFile: Opens a screenshot in the system's viewer.
    init(
        folders: @escaping () -> LibraryFolders,
        actions: Actions = Actions(),
        openMovie: @escaping (URL) -> Void,
        openFile: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        pasteboard: NSPasteboard = .general,
        trashItem: @escaping (LibraryItem) async throws -> Void = { try await LibraryStore.trash($0) }
    ) {
        self.folders = folders
        self.actions = actions
        self.openMovie = openMovie
        self.openFile = openFile
        self.pasteboard = pasteboard
        self.trashItem = trashItem
    }

    /// The items in the chosen section that match the search.
    var shown: [LibraryItem] {
        (items ?? []).filter { section.contains($0) && (search.isEmpty || $0.name.localizedStandardContains(search)) }
    }

    /// `shown` under date headers
    var shownGroups: [LibraryDateGroup] {
        LibraryDateGroup.groups(of: shown, now: .now, calendar: .current)
    }

    func count(in section: LibrarySection) -> Int {
        (items ?? []).count { section.contains($0) }
    }

    /// The folders being listed, e.g. to watch them.
    var watchedFolders: [URL] {
        let folders = folders()
        return [folders.recordings, folders.screenshots, folders.history]
    }

    // MARK: - Intents

    /// Reads the folders again, e.g. when something was saved since.
    func reload() async {
        let folders = folders()
        do {
            items = try await LibraryStore.items(recordings: folders.recordings, screenshots: folders.screenshots, history: folders.history)
            error = nil
        } catch {
            logger.error("Couldn't list the library: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func loadThumbnail(for item: LibraryItem) async {
        guard thumbnails[item.url] == nil else { return }
        thumbnails[item.url] = await LibraryStore.thumbnail(of: item, maximumSize: Self.thumbnailSize)
    }

    /// A recording opens in the editor, a screenshot in the system's viewer.
    func open(_ item: LibraryItem) {
        if item.isMovie {
            openMovie(item.url)
        } else {
            openFile(item.url)
        }
    }

    func reveal(_ item: LibraryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// A screenshot as its PNG, to paste anywhere; a movie as its file, to drop into an app.
    func copy(_ item: LibraryItem) {
        if !item.isMovie, let png = try? Data(contentsOf: item.url) {
            ImagePasteboard.copy(png: png, to: pasteboard)
        } else {
            pasteboard.clearContents()
            pasteboard.writeObjects([item.url as NSURL])
        }
    }

    /// Moves it to the Trash with its companions, and drops it from the list at once.
    func trash(_ item: LibraryItem) async {
        do {
            try await trashItem(item)
            items?.removeAll { $0.id == item.id }
            thumbnails[item.url] = nil
        } catch {
            logger.error("Couldn't move \(item.url.lastPathComponent) to the Trash: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
}
