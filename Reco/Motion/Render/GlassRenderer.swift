//
//  GlassRenderer.swift
//  Reco
//

import CoreImage
import simd

/// Lifted UI on glass (spec 0012, L0): the element, lifted bare, on a panel of dark glass in its shape,
/// the ground seen blurred through it, a rim of light round its outline and a soft shadow under it,
/// lit as its shot is (``SatinSetup/Glass``). Raycast's UI reads as a lit object this way; a page's own
/// flat fill and hairline read as a screenshot.
nonisolated enum GlassRenderer {

    /// A layer's panel in canvas pixels: its corner radius, its rim's width, and its height from the
    /// layer's top when it's shorter than the layer (a field whose results grow under it).
    nonisolated struct Shape: Equatable, Sendable {
        var radius: Double
        var rim: Double
        var height: Double?
    }

    /// The rim's width in CSS pixels: 0.08 of a cap height, 12 px at 14× on Raycast's pill.
    static let rimWidth = 0.87

    /// A glass shape's rim in canvas pixels: a card seen whole, not a control in macro.
    static let shapeRim = 2.5

    /// The panel under `layer` where `placement` puts it, over `field`, and the shadow it casts, in
    /// output pixels; the layer's content goes over the panel, clipped to it. `nil` for a layer not on
    /// glass, or a panel that can't be drawn.
    static func panel(
        under layer: MotionPlan.Layer, at placement: MotionPlan.Placement, lit glass: SatinSetup.Glass, over field: CIImage, plan: MotionPlan
    ) -> (body: CIImage, shadow: CIImage)? {
        let output = plan.outputSize
        let corners = placement.corners.map { CGPoint(x: $0.x * plan.outputScale, y: $0.y * plan.outputScale) }
        guard let shape = layer.glass, let kernel = FieldRenderer.kernel(named: "glassPanel"),
              let toFrame = projection(from: layer.size, to: corners), abs(toFrame.determinant) > 1e-12 else { return nil }
        let toPanel = toFrame.inverse
        let height = min(shape.height ?? layer.size.height, layer.size.height)
        // Pixels at 1080p per output pixel: the glass was measured at 1080p
        let unit = 1080 / min(output.width, output.height)
        let (blur, shadowBlur, drop) = (glass.blur / unit, glass.shadowBlur / unit, glass.shadowDrop / unit)
        // Its box in Core Image's space (y up), as far past the frame as its shadow reaches into it
        let across = corners.map(\.x)
        let down = corners.map { output.height - $0.y }
        let box = CGRect(
            x: across.min() ?? 0, y: down.min() ?? 0, width: (across.max() ?? 0) - (across.min() ?? 0), height: (down.max() ?? 0) - (down.min() ?? 0)
        )
        let reach = 3 * shadowBlur + drop
        let extent = box.insetBy(dx: -2, dy: -2).intersection(CGRect(origin: .zero, size: output).insetBy(dx: -reach, dy: -reach)).integral
        guard !extent.isNull, !extent.isEmpty else { return nil }
        // The ground through the glass: its light blurred in linear terms, a share of it let through
        let seen = field.clampedToExtent().applyingFilter("CISRGBToneCurveToLinear").applyingGaussianBlur(sigma: blur)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: glass.transmit, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: glass.transmit, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: glass.transmit, w: 0)
            ])
            .applyingFilter("CILinearToSRGBToneCurve")
        let row = { (index: Int) in CIVector(x: toPanel[0][index], y: toPanel[1][index], z: toPanel[2][index]) }
        let arguments: [Any] = [
            seen, field.clampedToExtent(),
            CIVector(x: output.width, y: output.height, z: unit, w: 0),
            CIVector(x: layer.size.width, y: height, z: min(shape.radius, min(layer.size.width, height) / 2), w: shape.rim),
            row(0), row(1), row(2),
            CIVector(x: glass.rimLevel, y: glass.rimLit, z: glass.rimSeen, w: glass.rimInner),
            CIVector(x: glass.glint, y: glass.glintDepth, z: glass.glintSource.x, w: glass.glintSource.y),
            CIVector(x: glass.pool.x, y: glass.pool.y, z: glass.poolRadius, w: glass.poolLevel),
            CIVector(x: glass.sheen.x, y: glass.sheen.y, z: glass.sheenAngle * .pi / 180, w: glass.sheenWidth),
            CIVector(x: glass.base, y: glass.sheenLevel, z: glass.sheenFall, w: glass.glintFall)
        ]
        guard let body = kernel.apply(extent: extent, roiCallback: { _, rect in rect.insetBy(dx: -2, dy: -2) }, arguments: arguments) else { return nil }
        // Cast by its coverage, down the frame
        let clear = CIVector(x: 0, y: 0, z: 0, w: 0)
        let shadow = body.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": clear, "inputGVector": clear, "inputBVector": clear, "inputAVector": CIVector(x: 0, y: 0, z: 0, w: glass.shadow)
        ]).transformed(by: CGAffineTransform(translationX: 0, y: -drop)).applyingGaussianBlur(sigma: shadowBlur)
        return (body, shadow)
    }

    /// The projection taking a rectangle `size` large (from its top-left corner) onto `corners`
    /// (top-left first, clockwise): Heckbert's square-to-quad mapping, after scaling to a unit square.
    static func projection(from size: CGSize, to corners: [CGPoint]) -> simd_double3x3? {
        guard corners.count == 4, size.width > 0, size.height > 0 else { return nil }
        let (topLeft, topRight, bottomRight, bottomLeft) = (corners[0], corners[1], corners[2], corners[3])
        let right = CGVector(dx: topRight.x - bottomRight.x, dy: topRight.y - bottomRight.y)
        let bottom = CGVector(dx: bottomLeft.x - bottomRight.x, dy: bottomLeft.y - bottomRight.y)
        // How far the quad is from a parallelogram
        let skew = CGVector(dx: topLeft.x - topRight.x + bottomRight.x - bottomLeft.x, dy: topLeft.y - topRight.y + bottomRight.y - bottomLeft.y)
        let determinant = right.dx * bottom.dy - bottom.dx * right.dy
        guard abs(determinant) > 1e-12 else { return nil }
        let across = (skew.dx * bottom.dy - bottom.dx * skew.dy) / determinant
        let down = (right.dx * skew.dy - skew.dx * right.dy) / determinant
        let square = simd_double3x3(rows: [
            [topRight.x - topLeft.x + across * topRight.x, bottomLeft.x - topLeft.x + down * bottomLeft.x, topLeft.x],
            [topRight.y - topLeft.y + across * topRight.y, bottomLeft.y - topLeft.y + down * bottomLeft.y, topLeft.y],
            [across, down, 1]
        ])
        return square * simd_double3x3(diagonal: [1 / size.width, 1 / size.height, 1])
    }
}
