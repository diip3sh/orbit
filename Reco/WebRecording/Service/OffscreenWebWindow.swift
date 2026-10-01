//
//  OffscreenWebWindow.swift
//  Reco
//

import AppKit

/// A borderless window off every display that holds a take's web view.
///
/// WebKit treats a page in an occluded window as hidden: `document.hidden` turns true,
/// `requestAnimationFrame` stops, and pages pause their media and carousels. Reporting the window
/// as visible keeps the page running as it would in front of the user (measured in spec 0005).
final class OffscreenWebWindow: NSWindow {

    init(size: CGSize) {
        super.init(
            contentRect: CGRect(origin: CGPoint(x: -100_000, y: -100_000), size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        collectionBehavior = [.transient, .ignoresCycle]
    }

    override var occlusionState: NSWindow.OcclusionState {
        .visible
    }

    override var canBecomeKey: Bool {
        false
    }
}
