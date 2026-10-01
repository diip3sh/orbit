//
//  Screenshot.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import CoreGraphics
import Foundation

/// A captured still, held in memory until the user saves it
nonisolated struct Screenshot: Sendable {

    /// Native pixels
    let image: CGImage

    /// Pixels per point of the captured content
    let scale: CGFloat

    /// When it was captured; names the saved file
    let date: Date

    /// Where an area capture was taken, in screen points (bottom-left origin); nil for windows and screens
    var region: CGRect?

    /// `Reco_Screenshot_<yyyy-MM-dd-HH.mm.ss>.png`, for Save and drag-out
    var filename: String {
        SettingsStore.filename(prefix: "Reco_Screenshot", fileExtension: "png", date: date)
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
        return Screenshot(image: image, scale: scale, date: date)
    }

    /// The size it had on screen
    var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }
}
