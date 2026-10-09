//
//  ScreenshotRedactor.swift
//  Reco
//

import CoreImage
import Vision

/// Pixelates a screenshot's private text (spec 0004, N9), off the main actor.
nonisolated enum ScreenshotRedactor {

    /// `screenshot` with its emails, phone numbers, card numbers and API keys pixelated, and how many were found;
    /// the same screenshot when there are none. The HDR picture is dropped: the hidden shot is saved as a PNG.
    ///
    /// Reads at Vision's accurate level: one still, so the 2 s a 4K frame takes are fine, and it reads more.
    @concurrent
    static func hidingSensitiveText(in screenshot: Screenshot) async throws -> (screenshot: Screenshot, count: Int) {
        let boxes = try await SensitiveTextFinder.boxes(in: screenshot.image, level: .accurate, minimumSize: 0)
        guard !boxes.isEmpty else { return (screenshot, 0) }
        let image = CIImage(cgImage: screenshot.image)
        let rects = boxes.map { box in
            CGRect(
                x: box.minX * image.extent.width, y: (1 - box.maxY) * image.extent.height,
                width: box.width * image.extent.width, height: box.height * image.extent.height
            ).integral
        }
        let hidden = MaskRenderer.apply(.pixelate, to: rects, of: image)
        guard let output = context.createCGImage(hidden, from: image.extent, format: .RGBA8, colorSpace: screenshot.image.colorSpace) else {
            throw CocoaError(.fileReadUnknown)
        }
        return (Screenshot(image: output, scale: screenshot.scale, date: screenshot.date, hdrImage: nil, region: screenshot.region), boxes.count)
    }

    /// Without colour management, so the pixels outside the boxes stay as captured
    private static let context = CIContext(options: [.cacheIntermediates: false, .workingColorSpace: NSNull()])
}
