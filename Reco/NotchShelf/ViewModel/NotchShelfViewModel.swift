//
//  NotchShelfViewModel.swift
//  Reco
//

import AppKit
import OSLog

/// One screen's notch shelf (spec 0013): whether it peeks or is open, opened and closed by the pointer
/// with a delay each way (`NotchMotion`), and the newest screenshots on it, which a click copies.
///
/// The delays are injectable like `RecordingCountdown`'s second, so tests don't wait for them.
@MainActor
@Observable
final class NotchShelfViewModel {

    /// The shelf shows this many screenshots
    nonisolated static let maximumItems = 20

    /// How long a tile says Copied
    nonisolated static let confirmationDuration = Duration.milliseconds(1200)

    /// A tile's picture at most, in pixels: twice its size on screen
    nonisolated static let thumbnailSize = CGSize(width: 280, height: 280)

    let geometry: NotchGeometry

    private(set) var isExpanded = false

    /// The pointer is on the shelf
    private(set) var isHovering = false

    /// The collapsed shape grows a little while the pointer is on it, until it opens
    var isPeeking: Bool { isHovering && !isExpanded }

    /// Where the shelf is on screen now, so where the pointer counts as on it: the notch (or pill) while
    /// idle, the peek while peeking, the panel while open
    var activeRect: CGRect {
        isExpanded ? geometry.expanded : isPeeking ? geometry.peek : geometry.collapsed
    }

    /// Newest first, or `nil` until the folders have been read
    private(set) var items: [LibraryItem]?

    private(set) var thumbnails: [URL: CGImage] = [:]

    /// The tile saying Copied
    private(set) var copiedURL: URL?

    @ObservationIgnored private let folders: () -> (screenshots: URL, history: URL)
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let sleep: @MainActor (Duration) async throws -> Void
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    @ObservationIgnored private var copyCount = 0
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Reco", category: "NotchShelf")

    /// - Parameters:
    ///   - folders: Where saved screenshots and the history are, read whenever the shelf opens since
    ///     Settings can change them.
    init(
        geometry: NotchGeometry,
        folders: @escaping () -> (screenshots: URL, history: URL),
        pasteboard: NSPasteboard = .general,
        sleep: @escaping @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.geometry = geometry
        self.folders = folders
        self.pasteboard = pasteboard
        self.sleep = sleep
    }

    // MARK: - Pointer

    /// The pointer is on the shelf: it peeks at once, opens after `NotchMotion.openDelay`, or stays open.
    /// - Returns: The task that opens it, which ends once the screenshots are read too.
    @discardableResult
    func pointerEntered() -> Task<Void, Never> {
        closeTask?.cancel()
        closeTask = nil
        isHovering = true
        if isExpanded { return Task {} }
        if let openTask { return openTask }

        let task = Task {
            // Read while the pointer rests, so the screenshots are there when it opens
            let reading = Task { await reload() }
            do {
                try await sleep(NotchMotion.openDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            isExpanded = true
            openTask = nil
            await reading.value
        }
        openTask = task
        return task
    }

    /// The pointer left the shelf: the peek ends and an opening is cancelled, or it closes after `NotchMotion.closeDelay`.
    /// - Returns: The task that closes it.
    @discardableResult
    func pointerExited() -> Task<Void, Never> {
        openTask?.cancel()
        openTask = nil
        isHovering = false
        if !isExpanded { return Task {} }
        if let closeTask { return closeTask }

        let task = Task {
            do {
                try await sleep(NotchMotion.closeDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            isExpanded = false
            closeTask = nil
        }
        closeTask = task
        return task
    }

    /// Closes at once, e.g. when the shelf is taken away for a screenshot
    func collapse() {
        openTask?.cancel()
        openTask = nil
        closeTask?.cancel()
        closeTask = nil
        isHovering = false
        isExpanded = false
    }

    // MARK: - Screenshots

    /// Reads the newest screenshots again and draws the pictures not drawn yet, then shows both at once, so a
    /// shelf that opens afterwards never has grey tiles. Until then the previous ones stay, so it never starts
    /// empty; the pictures of screenshots no longer shown are let go.
    func reload() async {
        let folders = folders()
        do {
            let all = try await LibraryStore.items(recordings: folders.screenshots, screenshots: folders.screenshots, history: folders.history)
            let shown = Array(all.filter { $0.kind == .screenshot }.prefix(Self.maximumItems))
            let drawn = await Self.thumbnails(of: shown.filter { thumbnails[$0.url] == nil })
            let urls = Set(shown.map(\.url))
            thumbnails = thumbnails.filter { urls.contains($0.key) }.merging(drawn) { _, new in new }
            items = shown
        } catch {
            logger.error("Couldn't list the screenshots: \(error.localizedDescription)")
            items = items ?? []
        }
    }

    /// The pictures of `items`, drawn side by side; a screenshot that can't be drawn has none
    @concurrent
    private static func thumbnails(of items: [LibraryItem]) async -> [URL: CGImage] {
        await withTaskGroup(of: (URL, CGImage?).self) { group in
            for item in items {
                group.addTask { (item.url, await LibraryStore.thumbnail(of: item, maximumSize: thumbnailSize)) }
            }
            var drawn: [URL: CGImage] = [:]
            for await (url, image) in group {
                drawn[url] = image
            }
            return drawn
        }
    }

    func loadThumbnail(for item: LibraryItem) async {
        guard thumbnails[item.url] == nil else { return }
        thumbnails[item.url] = await LibraryStore.thumbnail(of: item, maximumSize: Self.thumbnailSize)
    }

    /// Puts the screenshot on the pasteboard as PNG and shows Copied on its tile for a moment.
    func copy(_ item: LibraryItem) async {
        guard let png = await Self.contents(of: item.url) else {
            logger.error("Couldn't read \(item.url.lastPathComponent)")
            return
        }
        ImagePasteboard.copy(png: png, to: pasteboard)
        copyCount += 1
        let count = copyCount
        copiedURL = item.url
        try? await sleep(Self.confirmationDuration)
        // Another copy since has its own confirmation to end
        if copyCount == count {
            copiedURL = nil
        }
    }

    @concurrent
    private static func contents(of url: URL) async -> Data? {
        try? Data(contentsOf: url)
    }
}
