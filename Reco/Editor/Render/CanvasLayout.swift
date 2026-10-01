//
//  CanvasLayout.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo

/// Where the video sits on the output frame and what's around it, laid out once per plan.
nonisolated struct CanvasLayout: Sendable {

    /// The output frame's size in pixels.
    let size: CGSize

    /// The video's place on the frame in Core Image pixels, on whole pixels so its edges are sharp.
    let videoFrame: CGRect

    /// Maps the video's Core Image pixels onto ``videoFrame``.
    let videoTransform: CGAffineTransform

    /// The video's rounded shape, or `nil` when its corners are square.
    let videoMask: CIImage?

    /// The background with the video's shadow, drawn once, or `nil` when the video covers the frame.
    private(set) var backdrop: CIImage?

    /// The frame divided by what shows where, so each part is drawn from only that.
    let regions: [Region]

    /// A part of the frame, by what shows there.
    nonisolated enum Region: Equatable, Sendable {
        /// Only the ``CanvasLayout/backdrop``.
        case background(CGRect)

        /// Only the video, which covers it.
        case video(CGRect)

        /// The video's rounded corner, over the backdrop.
        case corner(CGRect)

        var rect: CGRect {
            switch self {
            case .background(let rect), .video(let rect), .corner(let rect): rect
            }
        }
    }
}

// MARK: - Building

extension CanvasLayout {

    /// How far the shadow spreads and drops, as shares of the frame's shorter side.
    nonisolated private static let shadowBlur = 0.03
    nonisolated private static let shadowDrop = 0.01

    /// The shadow is blurred this many times smaller and scaled back up, which looks the same: it's
    /// that blurry.
    nonisolated private static let shadowReduction = 8.0

    nonisolated private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])

    /// Core Image evaluates every overlay across the whole region it renders; in bands, it skips
    /// them where they aren't, and the padding doesn't read the video. Measured on an M1, Debug,
    /// under load, for a 4K frame with a ring and a chip: 3 ms p50 in 8 bands instead of 7 whole,
    /// and 4 ms instead of 9 on the default canvas.
    nonisolated static let videoBands = 8

    /// Lays out a `videoSize` video in `style`.
    /// - Parameters:
    ///   - shorterSide: The output's shorter side in pixels, or `nil` for the video's.
    ///   - background: The picture of an image background.
    nonisolated init(style: CanvasStyle, videoSize: CGSize, shorterSide: CGFloat?, background: CGImage?) {
        size = Self.size(for: videoSize, aspect: style.aspect, shorterSide: shorterSide)
        videoFrame = Self.videoFrame(for: videoSize, in: size, padding: style.padding)
        videoTransform = CGAffineTransform(scaleX: videoFrame.width / videoSize.width, y: videoFrame.height / videoSize.height)
            .concatenating(CGAffineTransform(translationX: videoFrame.minX, y: videoFrame.minY))

        let cornerRadius = style.cornerRadius * min(size.width, size.height)
        if cornerRadius > 0 {
            let shape = CIFilter.roundedRectangleGenerator()
            shape.extent = videoFrame
            shape.radius = Float(cornerRadius)
            shape.color = .white
            videoMask = shape.outputImage
        } else {
            videoMask = nil
        }
        backdrop = videoMask == nil && videoFrame == CGRect(origin: .zero, size: size)
            ? nil
            : Self.backdrop(style: style, size: size, videoFrame: videoFrame, cornerRadius: cornerRadius, image: background)
        regions = Self.regions(of: size, videoFrame: videoFrame, cornerRadius: cornerRadius)
    }

    /// The layout with its backdrop in `range`'s encoding (see ``OverlayImages/encoded(_:in:)``).
    nonisolated func encoded(in range: DynamicRange) -> CanvasLayout {
        var layout = self
        layout.backdrop = backdrop.map { OverlayImages.encoded($0, in: range) }
        return layout
    }

    /// The padding around the video, the video's rounded corners, and the rest of it in
    /// ``videoBands`` bands, on whole pixels.
    nonisolated static func regions(of size: CGSize, videoFrame frame: CGRect, cornerRadius: CGFloat) -> [Region] {
        let padding = [
            CGRect(x: 0, y: 0, width: size.width, height: frame.minY),
            CGRect(x: 0, y: frame.maxY, width: size.width, height: size.height - frame.maxY),
            CGRect(x: 0, y: frame.minY, width: frame.minX, height: frame.height),
            CGRect(x: frame.maxX, y: frame.minY, width: size.width - frame.maxX, height: frame.height)
        ]
        let corner = min(cornerRadius.rounded(.up), frame.width / 2, frame.height / 2)
        let interior = frame.insetBy(dx: 0, dy: corner)
        let bands = (0..<videoBands).map { band in
            let bottom = interior.minY + (interior.height * CGFloat(band) / CGFloat(videoBands)).rounded()
            let top = interior.minY + (interior.height * CGFloat(band + 1) / CGFloat(videoBands)).rounded()
            return CGRect(x: interior.minX, y: bottom, width: interior.width, height: top - bottom)
        }
        let video = bands + [
            CGRect(x: frame.minX + corner, y: frame.minY, width: frame.width - 2 * corner, height: corner),
            CGRect(x: frame.minX + corner, y: frame.maxY - corner, width: frame.width - 2 * corner, height: corner)
        ]
        let corners = corner > 0
            ? [
                CGRect(x: frame.minX, y: frame.minY, width: corner, height: corner),
                CGRect(x: frame.maxX - corner, y: frame.minY, width: corner, height: corner),
                CGRect(x: frame.minX, y: frame.maxY - corner, width: corner, height: corner),
                CGRect(x: frame.maxX - corner, y: frame.maxY - corner, width: corner, height: corner)
            ]
            : []
        return (padding.map(Region.background) + video.map(Region.video) + corners.map(Region.corner)).filter { !$0.rect.isEmpty }
    }

    /// The frame's size: `aspect`, with a shorter side of `shorterSide` or the video's. Sides are
    /// even, as 4:2:0 video needs; the video's own shape keeps its size.
    nonisolated static func size(for videoSize: CGSize, aspect: CanvasStyle.Aspect, shorterSide: CGFloat?) -> CGSize {
        let videoShorterSide = min(videoSize.width, videoSize.height)
        guard let ratio = aspect.ratio else {
            guard let shorterSide else { return videoSize }
            let scale = shorterSide / videoShorterSide
            return CGSize(width: even(videoSize.width * scale), height: even(videoSize.height * scale))
        }
        let shorter = shorterSide ?? videoShorterSide
        return ratio >= 1
            ? CGSize(width: even(shorter * ratio), height: even(shorter))
            : CGSize(width: even(shorter), height: even(shorter / ratio))
    }

    /// The video fitted inside the frame less `padding` on every side, centred, on whole pixels.
    nonisolated static func videoFrame(for videoSize: CGSize, in size: CGSize, padding: Double) -> CGRect {
        let inset = padding * min(size.width, size.height)
        let space = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        let scale = min(space.width / videoSize.width, space.height / videoSize.height)
        let width = (videoSize.width * scale).rounded()
        let height = (videoSize.height * scale).rounded()
        return CGRect(x: ((size.width - width) / 2).rounded(), y: ((size.height - height) / 2).rounded(), width: width, height: height)
    }

    nonisolated private static func even(_ length: CGFloat) -> CGFloat {
        (length / 2).rounded() * 2
    }

    /// The background with the video's shadow, rendered into a buffer that frames read in place.
    nonisolated private static func backdrop(
        style: CanvasStyle, size: CGSize, videoFrame: CGRect, cornerRadius: CGFloat, image: CGImage?
    ) -> CIImage {
        let bounds = CGRect(origin: .zero, size: size)
        var backdrop = background(of: style, bounds: bounds, image: image)
        if style.shadow > 0 {
            let shorterSide = min(size.width, size.height)
            let reduction = CGAffineTransform(scaleX: 1 / shadowReduction, y: 1 / shadowReduction)
            let shape = CIFilter.roundedRectangleGenerator()
            shape.extent = videoFrame.offsetBy(dx: 0, dy: -shadowDrop * shorterSide).applying(reduction)
            shape.radius = Float(cornerRadius / shadowReduction)
            shape.color = CIColor(red: 0, green: 0, blue: 0, alpha: 0.6 * style.shadow)
            let shadow = shape.outputImage?
                .applyingGaussianBlur(sigma: shadowBlur * shorterSide / shadowReduction)
                .transformed(by: reduction.inverted())
            backdrop = shadow?.composited(over: backdrop) ?? backdrop
        }

        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer
        )
        guard let buffer else { return backdrop.cropped(to: bounds) }
        context.render(backdrop, to: buffer, bounds: bounds, colorSpace: nil)
        // In sRGB like the other overlays, which HDR plans convert from
        return CIImage(cvPixelBuffer: buffer, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any])
    }

    nonisolated private static func background(of style: CanvasStyle, bounds: CGRect, image: CGImage?) -> CIImage {
        switch style.background {
        case .gradient:
            let gradient = CIFilter.linearGradient()
            gradient.point0 = CGPoint(x: bounds.minX, y: bounds.maxY)
            gradient.point1 = CGPoint(x: bounds.maxX, y: bounds.minY)
            gradient.color0 = CIColor(cgColor: style.gradientStart.cgColor)
            gradient.color1 = CIColor(cgColor: style.gradientEnd.cgColor)
            return gradient.outputImage ?? .empty()
        case .image where image != nil:
            // Fills the frame, cropped evenly on the sides that overflow
            let picture = image.map { CIImage(cgImage: $0) } ?? .empty()
            let scale = max(bounds.width / picture.extent.width, bounds.height / picture.extent.height)
            let placement = CGAffineTransform(scaleX: scale, y: scale).concatenating(CGAffineTransform(
                translationX: (bounds.width - picture.extent.width * scale) / 2, y: (bounds.height - picture.extent.height * scale) / 2
            ))
            return picture.transformed(by: placement, highQualityDownsample: true)
        case .color, .image:
            return CIImage(color: CIColor(cgColor: style.color.cgColor))
        case .transparent:
            return CIImage(color: .clear)
        }
    }
}
