//
//  SCContentFilter+CaptureScale.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import AppKit
@preconcurrency import ScreenCaptureKit

extension SCContentFilter {

    /// The point-to-pixel scale to size a capture of this filter with.
    ///
    /// Window captures cannot trust `SCContentFilter.pointPixelScale`: it reports the main
    /// display's scale for a window on a display arranged above the primary one, which sizes the
    /// video larger than ScreenCaptureKit renders and pads the output. Resolve the scale from the
    /// display the window actually occupies instead.
    var captureScale: CGFloat {
        let reported = CGFloat(pointPixelScale)

        guard style == .window, let window = includedWindows.first else {
            return reported
        }

        return CaptureSizeCalculator.windowScale(
            windowFrame: window.frame,
            displays: SCContentFilter.connectedDisplays(),
            fallback: reported
        )
    }

    /// The connected displays in the global CoreGraphics space that `SCWindow.frame` uses.
    private static func connectedDisplays() -> [DisplayGeometry] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            return DisplayGeometry(frame: CGDisplayBounds(displayID), scaleFactor: screen.backingScaleFactor)
        }
    }
}
