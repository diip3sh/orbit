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

/// The picker's grid of tiles: up to four across, two rows shown, the rest scrolled to.
nonisolated enum CaptureSourceGrid {

    static let tileWidth: CGFloat = 208
    /// 16:10, the shape of most screens and windows
    static let thumbnailHeight: CGFloat = 130
    /// The icon, title and subtitle under the picture
    static let labelHeight: CGFloat = 34
    static let spacing: CGFloat = 12
    static let padding: CGFloat = 16
    static let headerHeight: CGFloat = 28
    static let maximumColumns = 4
    static let visibleRows = 2

    static var tileHeight: CGFloat { thumbnailHeight + 6 + labelHeight }

    static func columns(for count: Int) -> Int {
        min(max(count, 1), maximumColumns)
    }

    /// The grid's own size for `count` tiles; while loading (`count` nil), one row of three
    static func size(for count: Int?) -> CGSize {
        let columns = count.map(columns(for:)) ?? 3
        let rows = count.map { min(max(1, Int((Double($0) / Double(maximumColumns)).rounded(.up))), visibleRows) } ?? 1
        let width = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * spacing + padding * 2
        let height = headerHeight + spacing + CGFloat(rows) * tileHeight + CGFloat(rows - 1) * spacing + padding * 2
        return CGSize(width: width, height: height)
    }
}
