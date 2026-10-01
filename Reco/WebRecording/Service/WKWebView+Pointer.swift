//
//  WKWebView+Pointer.swift
//  Reco
//

import AppKit
import WebKit

extension WKWebView {

    /// What the pointer does, sent to the page as a mouse event.
    enum PointerEvent {
        case move
        case press
        case release
    }

    /// Sends `event` at `point`, in the view's points from its top-left corner, straight to the page.
    ///
    /// A move goes as a right-button drag: WebKit hit-tests plain moves only in an active window and
    /// otherwise hands them to scrollbars alone, so `:hover` would never change. A drag is always
    /// hit-tested, and the page still sees no button held (`buttons` is 0) and no press (spec 0005).
    func sendPointer(_ event: PointerEvent, at point: CGPoint) {
        let type: NSEvent.EventType = switch event {
        case .move: .rightMouseDragged
        case .press: .leftMouseDown
        case .release: .leftMouseUp
        }
        let location = convert(CGPoint(x: point.x, y: isFlipped ? point.y : bounds.height - point.y), to: nil)
        guard let mouseEvent = NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window?.windowNumber ?? 0,
            context: nil,
            eventNumber: 0,
            clickCount: event == .move ? 0 : 1,
            pressure: event == .press ? 1 : 0
        ) else { return }

        switch event {
        case .move: rightMouseDragged(with: mouseEvent)
        case .press: mouseDown(with: mouseEvent)
        case .release: mouseUp(with: mouseEvent)
        }
    }
}
