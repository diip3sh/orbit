//
//  Screenshot.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// A captured still, held in memory until the user saves it
nonisolated struct Screenshot: Sendable {

    /// Native pixels, SDR: what the card, pins, copy and text recognition use
    let image: CGImage

    /// Pixels per point of the captured content
    let scale: CGFloat

    /// When it was captured; names the saved file
    let date: Date

    /// The same pixels in extended sRGB, brighter than white where the screen showed HDR, when HDR screenshots
    /// are on; what files are written from
    var hdrImage: CGImage?

    /// Where an area capture was taken, in screen points (bottom-left origin); nil for windows and screens
    var region: CGRect?

    /// The kinds of file screenshots are written as: PNG, or HEIC with a gain map for HDR
    static let contentTypes: [UTType] = [.png, .heic]

    /// `Reco_Screenshot_<yyyy-MM-dd-HH.mm.ss>.png` (`.heic` for HDR), for Save, drag-out and the history
    var filename: String {
        SettingsStore.filename(prefix: "Reco_Screenshot", fileExtension: hdrImage == nil ? "png" : "heic", date: date)
    }

    /// The part of a display shot inside `sourceRect` (display points, top-left origin); nil if it's outside
    func cropped(to sourceRect: CGRect) -> Screenshot? {
        let pixels = CGRect(
            x: sourceRect.minX * scale,
            y: sourceRect.minY * scale,
            width: sourceRect.width * scale,
            height: sourceRect.height * scale
        )
        guard let image = image.cropping(to: pixels.integral) else { return nil }
        return Screenshot(image: image, scale: scale, date: date, hdrImage: hdrImage?.cropping(to: pixels.integral))
    }

    /// The size it had on screen
    var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }
}
