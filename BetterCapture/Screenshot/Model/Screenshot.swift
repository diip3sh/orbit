//
//  Screenshot.swift
//  BetterCapture
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

    /// `BetterCapture_Screenshot_<yyyy-MM-dd-HH.mm.ss>.png`, for Save and drag-out
    var filename: String {
        SettingsStore.filename(prefix: "BetterCapture_Screenshot", fileExtension: "png", date: date)
    }

    /// The size it had on screen
    var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }
}
