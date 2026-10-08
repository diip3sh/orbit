//
//  RecorderViewModel+ContentSize.swift
//  Reco
//

@preconcurrency import ScreenCaptureKit
import AppKit

extension RecorderViewModel {

    /// The video's size in pixels for what `filter` records, with the area selection if there is one.
    func contentSize(of filter: SCContentFilter) -> CGSize {
        // Apply scale if Capture Native Resolution setting is enabled
        let applyScale: Bool = settings.captureNativeResolution

        // If area selection is active, use the source rect dimensions.
        // The sourceRect is already snapped to even pixel counts in presentAreaSelection().
        if let sourceRect = selectedSourceRect {
            return CaptureSizeCalculator.videoSize(
                contentRect: sourceRect,
                scale: CGFloat(filter.pointPixelScale),
                useNativeResolution: applyScale
            )
        }

        // Get the content rect from the filter
        let rect = filter.contentRect

        if rect.width > 0 && rect.height > 0 {
            return CaptureSizeCalculator.videoSize(
                contentRect: rect,
                scale: filter.captureScale,
                useNativeResolution: applyScale
            )
        }

        // Fallback to main screen size
        if let screen = NSScreen.main {
            return CGSize(
                width: applyScale ? screen.frame.width * screen.backingScaleFactor : screen.frame.width,
                height: applyScale ? screen.frame.height * screen.backingScaleFactor : screen.frame.height
            )
        }

        return CGSize(width: 1920, height: 1080)
    }
}
