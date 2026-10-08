//
//  LoupeView.swift
//  Reco
//

import AppKit

/// The frozen screen's pixels around the pointer, magnified with a grid between them and the pointer's pixel
/// outlined, so an edge can be aimed at to the pixel. ``LoupeGeometry`` says where it goes and what it shows.
@MainActor
final class LoupeView: NSView {

    private let image: CGImage

    /// The pixel shown at the centre, from the image's top-left corner.
    var pixel = CGPoint.zero {
        didSet {
            if pixel != oldValue { needsDisplay = true }
        }
    }

    init(image: CGImage) {
        self.image = image
        super.init(frame: CGRect(origin: .zero, size: CGSize(width: LoupeGeometry.size, height: LoupeGeometry.size)))
        wantsLayer = true
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = CGSize(width: 0, height: -4)
        self.shadow = shadow
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let edge = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 14, cornerHeight: 14, transform: nil)
        let cell = LoupeGeometry.pointsPerPixel

        context.saveGState()
        context.addPath(edge)
        context.clip()
        // Past the screen's edge there's nothing to show
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
        let region = LoupeGeometry.region(around: pixel, imageSize: CGSize(width: image.width, height: image.height))
        if let part = image.cropping(to: region) {
            // Pixels, not a blur of them
            context.interpolationQuality = .none
            context.draw(part, in: LoupeGeometry.drawingRect(of: region, around: pixel))
        }
        // The grid lies on the pixels' edges, which sit half a cell from the centre
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.2).cgColor)
        context.setLineWidth(1 / (window?.backingScaleFactor ?? 2))
        for offset in stride(from: cell / 2, through: bounds.width / 2, by: cell) {
            for line in [bounds.midX - offset, bounds.midX + offset] {
                context.move(to: CGPoint(x: line, y: 0))
                context.addLine(to: CGPoint(x: line, y: bounds.height))
                context.move(to: CGPoint(x: 0, y: line))
                context.addLine(to: CGPoint(x: bounds.width, y: line))
            }
        }
        context.strokePath()
        // The pointer's pixel, in white with a dark halo so it shows on anything
        let center = CGRect(x: bounds.midX - cell / 2, y: bounds.midY - cell / 2, width: cell, height: cell)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(3)
        context.stroke(center)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1)
        context.stroke(center)
        context.restoreGState()

        context.addPath(edge)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(1.5)
        context.strokePath()
    }
}
