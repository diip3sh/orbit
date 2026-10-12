//
//  MasonryPlacement.swift
//  Reco
//

import CoreGraphics

/// Where a masonry grid puts its tiles: columns of one width, each tile at its own height in the shortest
/// column so far (the leftmost of equal ones), in order. The columns end as evenly as the tiles allow, and
/// the reading order stays left to right, top to bottom.
nonisolated enum MasonryPlacement {

    struct Slot: Equatable {
        let column: Int
        let top: CGFloat
    }

    /// As many columns of at least `minimumColumnWidth` as fit `width`, and at least one.
    static func columnCount(width: CGFloat, minimumColumnWidth: CGFloat, spacing: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minimumColumnWidth + spacing)))
    }

    static func columnWidth(width: CGFloat, columns: Int, spacing: CGFloat) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    /// Each tile's slot, and the grid's height: its tallest column.
    static func slots(heights: [CGFloat], columns: Int, spacing: CGFloat) -> (slots: [Slot], height: CGFloat) {
        // Where the next tile in each column would start
        var tops = Array(repeating: CGFloat(0), count: max(1, columns))
        var slots: [Slot] = []
        slots.reserveCapacity(heights.count)
        for height in heights {
            let column = tops.indices.min { tops[$0] < tops[$1] } ?? 0
            slots.append(Slot(column: column, top: tops[column]))
            tops[column] += height + spacing
        }
        return (slots, heights.isEmpty ? 0 : (tops.max() ?? 0) - spacing)
    }
}
