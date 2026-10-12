//
//  EqualWidthRow.swift
//  Reco
//

import SwiftUI

/// Its subviews side by side at one width when the row holds each at the widest one's own width, else one above
/// the other at the row's width. A `ViewThatFits` of an `HStack` measured each button at its own width, then the
/// stack split the row evenly: in the 380 pt export column, "Copy to Clipboard ⌘↩" was cut to "Copy to Clipbo…".
struct EqualWidthRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? sideBySideWidth(of: subviews)
        let cell = cellProposal(in: width, for: subviews)
        let heights = subviews.map { $0.sizeThatFits(cell).height }
        let height = fitsSideBySide(in: width, subviews)
            ? heights.max() ?? 0
            : heights.reduce(0, +) + spacing * CGFloat(subviews.count - 1)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = cellProposal(in: bounds.width, for: subviews)
        if fitsSideBySide(in: bounds.width, subviews) {
            var left = bounds.minX
            for subview in subviews {
                subview.place(at: CGPoint(x: left, y: bounds.midY), anchor: .leading, proposal: cell)
                left += (cell.width ?? 0) + spacing
            }
        } else {
            var top = bounds.minY
            for subview in subviews {
                subview.place(at: CGPoint(x: bounds.minX, y: top), proposal: cell)
                top += subview.sizeThatFits(cell).height + spacing
            }
        }
    }

    /// The row's width with every subview at the widest one's own width.
    private func sideBySideWidth(of subviews: Subviews) -> CGFloat {
        let widest = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        return widest * CGFloat(subviews.count) + spacing * CGFloat(subviews.count - 1)
    }

    private func fitsSideBySide(in width: CGFloat, _ subviews: Subviews) -> Bool {
        sideBySideWidth(of: subviews) <= width
    }

    private func cellProposal(in width: CGFloat, for subviews: Subviews) -> ProposedViewSize {
        guard fitsSideBySide(in: width, subviews) else { return ProposedViewSize(width: width, height: nil) }
        let count = CGFloat(subviews.count)
        return ProposedViewSize(width: (width - spacing * (count - 1)) / count, height: nil)
    }
}
