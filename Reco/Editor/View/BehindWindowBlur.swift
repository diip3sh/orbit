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

extension View {

    /// A column beside the content (an inspector, the Library's sidebar) on the blurred desktop, tinted with the
    /// panel colour so text keeps to the theme over a bright wallpaper.
    func translucentColumn() -> some View {
        background {
            ZStack {
                BehindWindowBlur()
                // Not yet checked by eye: lower shows more desktop, higher reads more solid
                EditorTheme.panel.opacity(0.45)
            }
            .ignoresSafeArea()
        }
    }
}
