//
//  LoupeGeometry.swift
//  Reco
//

import CoreGraphics

/// Where the area selection's loupe sits and what it shows: the frozen screen's pixels around the pointer,
/// magnified, with the pointer's pixel at the centre. Points are in a view with a bottom-left origin; pixels
/// count from the image's top-left corner.
nonisolated enum LoupeGeometry {

    /// The loupe's side, in points.
    static let size: CGFloat = 120

    /// How big each screen pixel is drawn, in points: 4 shows 30 pixels across, each with room for a grid line.
    static let pointsPerPixel: CGFloat = 4

    /// From the pointer to the loupe's nearest edge, in points, so the loupe never covers what's aimed at.
    static let gap: CGFloat = 20

    /// The loupe's frame below and to the right of `pointer`, or on the other side of it where `bounds`' edge is
    /// in the way.
    static func frame(beside pointer: CGPoint, in bounds: CGRect) -> CGRect {
        let left = pointer.x + gap + size <= bounds.maxX ? pointer.x + gap : pointer.x - gap - size
        let bottom = pointer.y - gap - size >= bounds.minY ? pointer.y - gap - size : pointer.y + gap
        return CGRect(x: left, y: bottom, width: size, height: size)
    }

    /// The pixel under `pointer` in an `imageSize` image of `bounds`, inside the image: the pointer on the view's
    /// right or top edge is over its last column or row.
    static func pixel(under pointer: CGPoint, in bounds: CGRect, imageSize: CGSize) -> CGPoint {
        let scale = imageSize.width / bounds.width
        return CGPoint(
            x: min(max(((pointer.x - bounds.minX) * scale).rounded(.down), 0), imageSize.width - 1),
            y: min(max(((bounds.maxY - pointer.y) * scale).rounded(.down), 0), imageSize.height - 1)
        )
    }

    /// The pixels of an `imageSize` image the loupe shows around `pixel`: the ones within its reach that the image has.
    static func region(around pixel: CGPoint, imageSize: CGSize) -> CGRect {
        let reach = (size / pointsPerPixel / 2).rounded(.up)
        return CGRect(x: pixel.x - reach, y: pixel.y - reach, width: 2 * reach + 1, height: 2 * reach + 1)
            .intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// Where `region` is drawn in the loupe (a bottom-left origin), each pixel ``pointsPerPixel`` big, so that `pixel`
    /// is at the centre.
    static func drawingRect(of region: CGRect, around pixel: CGPoint) -> CGRect {
        let center = size / 2
        let height = region.height * pointsPerPixel
        return CGRect(
            x: center - pointsPerPixel / 2 + (region.minX - pixel.x) * pointsPerPixel,
            y: center + pointsPerPixel / 2 + (pixel.y - region.minY) * pointsPerPixel - height,
            width: region.width * pointsPerPixel,
            height: height
        )
    }
}
