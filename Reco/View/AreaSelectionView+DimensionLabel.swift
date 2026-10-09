//
//  AreaSelectionView+DimensionLabel.swift
//  Reco
//

import AppKit
import SwiftUI

extension AreaSelectionView {

    /// The selection's size in even pixels, as the recorder rounds it, under the selection or above it at the bottom edge
    func drawDimensionLabel(in context: CGContext) {
        let scale = screen.backingScaleFactor
        let pixelWidth = selectionRect.width * scale
        let pixelHeight = selectionRect.height * scale

        // Snap to even pixel counts (matches the formula used by RecorderViewModel)
        let evenWidth = Int(ceil(pixelWidth / 2) * 2)
        let evenHeight = Int(ceil(pixelHeight / 2) * 2)

        let text = "\(evenWidth) × \(evenHeight)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.theme(.callout, weight: .medium, .mono),
            .foregroundColor: NSColor.white
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        let padding: CGFloat = 6
        let backgroundRect = CGRect(
            x: selectionRect.midX - (size.width + padding * 2) / 2,
            y: selectionRect.minY - size.height - padding * 2 - 8,
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )

        // Ensure label stays within view bounds
        var adjustedRect = backgroundRect
        if adjustedRect.minY < 0 {
            adjustedRect.origin.y = selectionRect.maxY + 8
        }
        adjustedRect.origin.x = max(4, min(adjustedRect.origin.x, bounds.width - adjustedRect.width - 4))

        // Draw background
        context.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        let bgPath = CGPath(roundedRect: adjustedRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
        context.addPath(bgPath)
        context.fillPath()

        // Draw text
        let textPoint = CGPoint(
            x: adjustedRect.origin.x + padding,
            y: adjustedRect.origin.y + padding
        )
        attributedString.draw(at: textPoint)
    }
}
