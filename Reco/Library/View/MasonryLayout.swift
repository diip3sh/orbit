//
//  MasonryLayout.swift
//  Reco
//

import SwiftUI

/// Tiles in columns at their own heights (`MasonryPlacement`): each is offered a column's width and keeps the
/// height it asks for, as a picture with its aspect ratio does.
struct MasonryLayout: Layout {
    var minimumColumnWidth: CGFloat
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? minimumColumnWidth
        return CGSize(width: width, height: arrangement(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrangement(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let slot = arrangement.slots[index]
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(slot.column) * (arrangement.columnWidth + spacing), y: bounds.minY + slot.top),
                proposal: ProposedViewSize(width: arrangement.columnWidth, height: arrangement.heights[index])
            )
        }
    }

    private struct Arrangement {
        let columnWidth: CGFloat
        let heights: [CGFloat]
        let slots: [MasonryPlacement.Slot]
        let height: CGFloat
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> Arrangement {
        let columns = MasonryPlacement.columnCount(width: width, minimumColumnWidth: minimumColumnWidth, spacing: spacing)
        let columnWidth = MasonryPlacement.columnWidth(width: width, columns: columns, spacing: spacing)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height }
        let placement = MasonryPlacement.slots(heights: heights, columns: columns, spacing: spacing)
        return Arrangement(columnWidth: columnWidth, heights: heights, slots: placement.slots, height: placement.height)
    }
}
