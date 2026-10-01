//
//  CaptureSizeCalculator.swift
//  Reco
//
//  Created by Joshua Sattler on 29.08.26.
//

import CoreGraphics
import Foundation

/// Derives the pixel dimensions a capture should be configured and encoded at.
enum CaptureSizeCalculator {

    /// Resolves the point-to-pixel scale for a window from the display it occupies.
    ///
    /// `SCContentFilter.pointPixelScale` reports the *main* display's scale for windows living on
    /// a display arranged above the primary one, because such a display has a negative Y origin in
    /// the global CoreGraphics space and the framework's lookup falls back to the main display. On
    /// a 2x built-in with a 1x external above it that yields 2.0 instead of 1.0, so the stream is
    /// configured at twice the size ScreenCaptureKit renders and the output gains blank padding to
    /// the right of and below the content.
    ///
    /// - Parameters:
    ///   - windowFrame: The window's frame in global CoreGraphics points.
    ///   - displays: The connected displays, in the same coordinate space.
    ///   - fallback: The scale to use when the window overlaps no known display.
    /// - Returns: The scale of the display covering most of the window.
    static func windowScale(windowFrame: CGRect, displays: [DisplayGeometry], fallback: CGFloat) -> CGFloat {
        // A window can straddle two displays, so pick the one showing most of it rather than the
        // one containing some arbitrary corner.
        let overlaps = displays.compactMap { display -> (scale: CGFloat, area: CGFloat)? in
            let intersection = display.frame.intersection(windowFrame)
            guard !intersection.isNull, !intersection.isEmpty else { return nil }
            return (display.scaleFactor, intersection.width * intersection.height)
        }

        guard let best = overlaps.max(by: { $0.area < $1.area }) else { return fallback }
        return best.scale
    }

    /// The dimensions to capture and encode at.
    ///
    /// - Parameters:
    ///   - contentRect: The content to capture, in points.
    ///   - scale: The display's point-to-pixel scale.
    ///   - useNativeResolution: Whether to capture at the display's native pixel density.
    /// - Returns: The video dimensions, in pixels when capturing natively and in points otherwise.
    static func videoSize(contentRect: CGRect, scale: CGFloat, useNativeResolution: Bool) -> CGSize {
        guard useNativeResolution else { return contentRect.size }
        return CGSize(width: contentRect.width * scale, height: contentRect.height * scale)
    }

    /// Converts an area selection to a display capture's `sourceRect`.
    ///
    /// Flips from global screen points (bottom-left origin) to display points with a top-left
    /// origin, and grows the size to even pixel counts for codec compatibility.
    /// - Parameters:
    ///   - screenRect: The selection, in global screen points.
    ///   - screenFrame: The frame of the screen it was made on, same space.
    ///   - scale: That screen's backing scale factor.
    static func sourceRect(for screenRect: CGRect, in screenFrame: CGRect, scale: CGFloat) -> CGRect {
        let localX = screenRect.minX - screenFrame.minX
        let localY = screenRect.minY - screenFrame.minY
        let evenPixelWidth = ceil(screenRect.width * scale / 2) * 2
        let evenPixelHeight = ceil(screenRect.height * scale / 2) * 2
        return CGRect(
            x: localX,
            y: screenFrame.height - localY - screenRect.height,
            width: evenPixelWidth / scale,
            height: evenPixelHeight / scale
        )
    }
}
