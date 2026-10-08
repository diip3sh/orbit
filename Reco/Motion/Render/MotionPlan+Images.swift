//
//  MotionPlan+Images.swift
//  Reco
//

import CoreGraphics
import CoreImage
import ImageIO

// MARK: - Images

/// The images a plan draws once: layer contents, shapes, shadows.
extension MotionPlan {

    /// Draws shadows once; without color management, as frames are.
    nonisolated private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    /// The image's silhouette in black at the shadow's opacity, blurred, with `padding` canvas pixels
    /// around it, drawn into a bitmap.
    nonisolated static func shadow(of image: CIImage, shadow: LayerShadow, padding: Double, scale: Double) -> CIImage? {
        let silhouette = silhouette(of: image, shadow: shadow, padding: padding, scale: scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = context.createCGImage(silhouette, from: silhouette.extent, format: .RGBA8, colorSpace: space) else { return nil }
        return CIImage(cgImage: bitmap)
    }

    /// The image's silhouette in the shadow's colour (black without one) at its opacity, blurred, with `padding`
    /// canvas pixels around it: a recipe, drawn when its frame is. A morphing shape's glow is made per frame from it.
    nonisolated static func silhouette(of image: CIImage, shadow: LayerShadow, padding: Double, scale: Double) -> CIImage {
        let inset = padding * scale
        let color = shadow.color ?? RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        let silhouette = image
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: min(max(shadow.opacity * color.alpha, 0), 1)),
                "inputBiasVector": CIVector(x: color.red, y: color.green, z: color.blue, w: 0)
            ])
            .transformed(by: CGAffineTransform(translationX: inset, y: inset))
            .applyingGaussianBlur(sigma: shadow.radius * scale)
        let bounds = CGRect(x: 0, y: 0, width: image.extent.width + 2 * inset, height: image.extent.height + 2 * inset).integral
        return silhouette.cropped(to: bounds)
    }

    nonisolated static func image(
        of content: LayerContent, scale: Double, size: CGSize, bundle: URL, lifts: [String: UILiftCache.Lift]
    ) -> CIImage? {
        switch content {
        case .text(let text):
            return TextImage(text, scale: scale).image.map { CIImage(cgImage: $0) }
        case .shape(let shape) where shape.isGlyph:
            return ShapeGlyph.image(of: shape, scale: scale)
        case .shape(let shape) where (shape.stroke ?? 0) > 0:
            return ShapeMorph.image(of: ShapeMorph.State(size: shape.size, radius: shape.cornerRadius, color: shape.color, stroke: shape.stroke ?? 0), scale: scale)
        case .shape(let shape):
            let color = shape.color
            return roundedRectangle(
                size: shape.size, radius: shape.cornerRadius, scale: scale, color: CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
            )
        case .image(let image):
            return picture(at: bundle.appending(path: image.path), pixels: CGSize(width: size.width * scale, height: size.height * scale))
        case .lifted(let lifted):
            return lifts[lifted.asset].flatMap { picture(at: $0.url, pixels: CGSize(width: size.width * scale, height: size.height * scale)) }
        case .group:
            return nil
        }
    }

    /// A rounded rectangle `size` canvas pixels large at `scale` pixels per canvas pixel.
    nonisolated static func roundedRectangle(size: CGSize, radius: Double, scale: Double, color: CIColor = .white) -> CIImage {
        CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: CGRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)),
            "inputRadius": radius * scale,
            "inputColor": color
        ])?.outputImage ?? CIImage.empty()
    }

    /// The image file at `url` read at most `pixels` large, stretched to that rounded to whole pixels,
    /// as an `<img>` with both dimensions set. Whole: `CIPerspectiveTransform` maps an image's extent
    /// out to whole pixels, so a 5800.3 px wide lift drew 0.6 px off the film's (spec 0012, phase 2).
    nonisolated static func picture(at url: URL, pixels: CGSize) -> CIImage? {
        let pixels = CGSize(width: max(pixels.width.rounded(), 1), height: max(pixels.height.rounded(), 1))
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(pixels.width, pixels.height).rounded(.up)
              ] as CFDictionary) else { return nil }
        return CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(
            scaleX: pixels.width / CGFloat(cgImage.width), y: pixels.height / CGFloat(cgImage.height)
        ))
    }

    /// How far the lit region fades into the dimmed rest: a share of the layer's height (the blur's
    /// sigma). Cut hard, the edge drew a line across the UI.
    nonisolated static let focusFeather = 0.03

    /// The layer darkened by `dim` outside `region` (canvas pixels from the top-left corner of a
    /// layer `height` tall), and out of focus: 10 px of blur at full dim, as the reference's far
    /// planes. A take's frame has the movie's pixels, so the scale is the image's.
    nonisolated static func focused(_ image: CIImage, on region: CGRect, dim: Double, height: Double) -> CIImage {
        let scale = image.extent.height / height
        let lit = CGRect(
            x: image.extent.minX + region.minX * scale, y: image.extent.minY + (height - region.maxY) * scale, width: region.width * scale, height: region.height * scale
        )
        let kept = 1 - min(dim, 1)
        let darkened = image.clampedToExtent().applyingGaussianBlur(sigma: min(dim, 1) * 10 * scale).cropped(to: image.extent)
            .applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: kept, y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: kept, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: kept, w: 0)
            ])
        let mask = CIImage(color: .white).cropped(to: lit).applyingGaussianBlur(sigma: focusFeather * height * scale).cropped(to: image.extent)
        return image.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: darkened, kCIInputMaskImageKey: mask])
    }

    /// A layer's image as its focus leaves it, drawn into a bitmap; `nil` without a focus.
    nonisolated static func focusedImage(of image: CIImage, layer: Layer) -> CIImage? {
        guard let region = layer.region, layer.mostDim > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = context.createCGImage(focused(image, on: region, dim: layer.mostDim, height: layer.size.height), from: image.extent, format: .RGBA8, colorSpace: space)
        else { return nil }
        return CIImage(cgImage: bitmap).transformed(by: CGAffineTransform(translationX: image.extent.minX, y: image.extent.minY))
    }
}
