//
//  LibraryScatter.swift
//  Reco
//

import CoreGraphics
import Foundation

/// A picture opened over the Library's grid, moving as kosmica.app's gallery does (its `script.js`, read on
/// 2026-10-15): the picture grows out of its tile to fit the view, and every other tile is pushed straight away
/// from it, less the further it is, as it fades. Positions are in the grid's content, so scrolling doesn't move them.
nonisolated struct LibraryScatter: Identifiable, Equatable, Sendable {
    /// Each click opens its own: a picture opened while another is on its way back starts from its own tile.
    let id = UUID()

    /// What shows: the clicked picture, or the one the arrows moved to.
    var item: LibraryItem

    /// The opened tile's centre in the grid's content.
    var origin: CGPoint

    /// False while the picture springs back into its tile, when every tile heads home.
    var isOpen = true

    /// How far a tile at the opened one's centre would be pushed, and the distance over which the push falls by a
    /// factor of e: kosmica's 5.1 × its 150 px rows and 961 px, taken as points.
    static let push: CGFloat = 765
    static let reach: CGFloat = 961

    /// Where the tile centred at `centre` goes: away from the opened tile by `push · e^(−distance / reach)` while
    /// open, so the opened tile itself (distance 0) stays put; home while closing.
    func offset(ofTileAt centre: CGPoint) -> CGSize {
        let away = CGSize(width: centre.x - origin.x, height: centre.y - origin.y)
        let distance = (away.width * away.width + away.height * away.height).squareRoot()
        guard isOpen, distance > 0 else { return .zero }
        let push = Self.push * exp(-distance / Self.reach)
        return CGSize(width: away.width / distance * push, height: away.height / distance * push)
    }

    /// The picture `offset` places from `item` along `items`, the grid's order, counting only what opens over the
    /// grid (movies open in the editor); `nil` past either end.
    static func picture(_ offset: Int, from item: LibraryItem, in items: [LibraryItem]) -> LibraryItem? {
        let pictures = items.filter { !$0.isMovie }
        guard let index = pictures.firstIndex(of: item), pictures.indices.contains(index + offset) else { return nil }
        return pictures[index + offset]
    }

    /// The largest rectangle of `aspectRatio` (width over height) that fits `bounds`, centred in it.
    static func fitted(aspectRatio: Double, in bounds: CGRect) -> CGRect {
        let size = bounds.width / bounds.height > aspectRatio
            ? CGSize(width: bounds.height * aspectRatio, height: bounds.height)
            : CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
    }
}
