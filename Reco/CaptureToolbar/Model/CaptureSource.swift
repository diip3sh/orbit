//
//  CaptureSource.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A window or display offered in the capture toolbar's picker, with what its tile shows.
nonisolated struct CaptureSource: Identifiable, Equatable, Sendable {

    enum Kind: Sendable {
        case window, display
    }

    /// The window's or the display's ID
    let id: UInt32
    let title: String
    /// The window's app, or the display's size
    let subtitle: String
    /// The app owning the window, for its icon
    let processID: pid_t?

    /// Windows smaller than this are panels, palettes and status items, not something to record
    static let minimumWindowSize = CGSize(width: 64, height: 64)

    /// Whether a window is offered: an ordinary window (layer 0) on screen, big enough to record,
    /// of another app than Reco.
    static func offers(layer: Int, frame: CGRect, bundleID: String?, isOnScreen: Bool, ownBundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty, bundleID != ownBundleID else { return false }
        return layer == 0
            && isOnScreen
            && frame.width >= minimumWindowSize.width
            && frame.height >= minimumWindowSize.height
    }

    /// A window's title, or its app's name when it has none
    static func title(windowTitle: String?, appName: String) -> String {
        guard let windowTitle, !windowTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return appName }
        return windowTitle
    }
}

/// The picker's row of tiles: up to four shown, the rest scrolled to sideways.
nonisolated enum CaptureSourceGrid {

    static let tileWidth: CGFloat = 208
    /// 16:10, the shape of most screens and windows
    static let thumbnailHeight: CGFloat = 130
    /// The icon, title and subtitle under the picture
    static let labelHeight: CGFloat = 34
    static let spacing: CGFloat = 12
    /// The tiles' room inside the frost around them
    static let padding: CGFloat = 10
    static let maximumColumns = 4

    static var tileHeight: CGFloat { thumbnailHeight + 6 + labelHeight }

    /// A message on its own, with no tiles: a spinner, a failure, or nothing to record. Two tiles wide,
    /// so the longest one wraps over a few lines
    static var messageSize: CGSize {
        CGSize(width: tileWidth * 2 + spacing + padding * 2, height: 120)
    }

    /// The tile `offset` places from `id` in the row, kept inside it; the first when nothing is highlighted
    static func neighbour<ID: Equatable>(of id: ID?, by offset: Int, in ids: [ID]) -> ID? {
        guard !ids.isEmpty else { return nil }
        guard let id, let index = ids.firstIndex(of: id) else { return ids.first }
        return ids[min(max(index + offset, 0), ids.count - 1)]
    }

    static func columns(for count: Int) -> Int {
        min(max(count, 1), maximumColumns)
    }

    /// The row's own size for `count` tiles: one row, never wider than `maximumColumns` tiles
    static func size(for count: Int) -> CGSize {
        let columns = columns(for: count)
        let width = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * spacing + padding * 2
        return CGSize(width: width, height: tileHeight + padding * 2)
    }
}
