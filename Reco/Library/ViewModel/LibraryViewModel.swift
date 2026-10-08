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
    }

    var section = LibrarySection.all
    var search = ""

    /// The Filter menu's shape, `nil` for any.
    var orientation: LibraryOrientation?
    var sort = LibrarySort.newestFirst

    /// Newest first, or `nil` until the folders have been read.
    private(set) var items: [LibraryItem]?

    /// The items' pictures, loaded as their tiles appear.
    private(set) var thumbnails: [URL: CGImage] = [:]

    /// Each item's width over height, read once when it is first listed, for the masonry grid and the shape
    /// filter. By item, not URL: an export written again under its name may have another shape.
    private(set) var aspectRatios: [LibraryItem: Double] = [:]

    /// Why the folders couldn't be read, or an item couldn't be trashed.
    var error: String?

    let actions: Actions

    /// A tile's picture at most, in pixels: twice a wide column's 320 pt across, and as tall as the item's shape
    /// needs, up to twice that.
    static func thumbnailSize(aspectRatio: Double?) -> CGSize {
        CGSize(width: 640, height: min(1280, 640 / (aspectRatio ?? 1.6)))
    }

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

    /// The items in the chosen section that match the search and the shape, in the chosen order. With a shape
    /// chosen, an item whose shape couldn't be read is left out.
    var shown: [LibraryItem] {
        sort.sorted((items ?? []).filter { item in
            section.contains(item)
                && (search.isEmpty || item.name.localizedStandardContains(search))
                && (orientation == nil || aspectRatios[item].map(LibraryOrientation.init) == orientation)
        })
    }

    /// `shown` under date headers, the oldest first when so sorted.
    var shownGroups: [LibraryDateGroup] {
        let groups = LibraryDateGroup.groups(of: shown, now: .now, calendar: .current)
        guard sort == .oldestFirst else { return groups }
        return groups.reversed().map { LibraryDateGroup(title: $0.title, items: $0.items.reversed()) }
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
            let listed = try await LibraryStore.items(recordings: folders.recordings, screenshots: folders.screenshots, history: folders.history)
            // Before the items show, so the grid is laid out once in its final shape
            let unread = listed.filter { aspectRatios[$0] == nil }
            aspectRatios.merge(await LibraryStore.aspectRatios(of: unread)) { $1 }
            items = listed
            error = nil
        } catch {
            logger.error("Couldn't list the library: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    func loadThumbnail(for item: LibraryItem) async {
        guard thumbnails[item.url] == nil else { return }
        thumbnails[item.url] = await LibraryStore.thumbnail(of: item, maximumSize: Self.thumbnailSize(aspectRatio: aspectRatios[item]))
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

    /// A screenshot as its PNG, to paste anywhere; a movie or GIF as its file, to drop into an app.
    func copy(_ item: LibraryItem) {
        if item.kind == .screenshot, let png = try? Data(contentsOf: item.url) {
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
