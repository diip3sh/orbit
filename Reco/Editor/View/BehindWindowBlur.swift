//
//  BehindWindowBlur.swift
//  Reco
//

import AppKit
import SwiftUI

/// The desktop behind the window, blurred, as Raycast's window shows it. Only works in a window that isn't opaque
/// (`EditorWindowManager.makeWindow`) over a part of it nothing else in the window draws under. AppKit makes it
/// solid with Reduce Transparency.
struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        // Stays see-through when the window isn't key, as Raycast's does
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
