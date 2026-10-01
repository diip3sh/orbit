//
//  NSScreen+DisplayID.swift
//  Reco
//
//  Created by Diip3sh on 01.10.26.
//

import AppKit

extension NSScreen {

    /// The CoreGraphics display this screen shows, which ScreenCaptureKit's `SCDisplay.displayID` matches
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
