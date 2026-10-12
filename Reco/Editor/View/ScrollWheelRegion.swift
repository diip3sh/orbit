//
//  ScrollWheelRegion.swift
//  Reco
//
//  Created by Diip3sh on 10.10.26.
//

import AppKit
import SwiftUI

/// Reports scroll wheel events over a view without taking clicks: a local monitor sees them before
/// dispatch and answers only those inside the view, so the timeline can pan and ⌘-zoom while every
/// drag and click still goes to the views on top.
struct ScrollWheelRegion: NSViewRepresentable {

    /// Handles an event over the view; returns true when it was used, so it goes no further.
    let onScroll: (NSEvent, CGPoint) -> Bool

    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: ScrollWheelView, context: Context) {
        view.onScroll = onScroll
    }

    final class ScrollWheelView: NSView {
        var onScroll: ((NSEvent, CGPoint) -> Bool)?

        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window === window else { return event }
                let point = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(point) else { return event }
                return self.onScroll?(event, point) == true ? nil : event
            }
        }

        deinit {
            MainActor.assumeIsolated {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
        }
    }
}
