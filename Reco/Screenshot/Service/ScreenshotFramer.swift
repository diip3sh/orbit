//
//  ScreenshotFramer.swift
//  Reco
//

import CoreImage

/// Puts a screenshot on a background (spec 0004, N14), off the main actor: the editor's canvas around a still.
nonisolated enum ScreenshotFramer {

    /// `screenshot` on `background`, in its own shape and at its own pixels: the canvas is sized so the shot keeps
    /// them inside the padding (`CanvasLayout.nativeShorterSide`), as an export at the original size does. With Auto
    /// Balance, borders of one colour are trimmed first. The HDR picture is dropped: the framed shot is saved as a PNG.
    @concurrent
    static func framing(_ screenshot: Screenshot, with background: ScreenshotBackground) async throws -> Screenshot {
        let image = background.autoBalances ? UniformBorders.trimmed(screenshot.image) : screenshot.image
        var picture: CGImage?
        if background.canvas.background == .image, let bookmark = background.canvas.imageBookmark {
            picture = await BackgroundImageLoader.image(from: bookmark)?.image
        }
        let size = CGSize(width: image.width, height: image.height)
        let style = background.layoutStyle
        let layout = CanvasLayout(
            style: style, videoSize: size, shorterSide: CanvasLayout.nativeShorterSide(for: size, style: style), background: picture
        )
        let framed = FrameRenderer.framed(CIImage(cgImage: image).transformed(by: layout.videoTransform), on: layout)
        let bounds = CGRect(origin: .zero, size: layout.size)
        guard let output = context.createCGImage(framed, from: bounds, format: .RGBA8, colorSpace: screenshot.image.colorSpace) else {
            throw CocoaError(.fileReadUnknown)
        }
        return Screenshot(image: output, scale: screenshot.scale, date: screenshot.date, hdrImage: nil, region: screenshot.region)
    }

    /// Without colour management, so the shot's pixels stay as captured, like the editor's frames
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
}
