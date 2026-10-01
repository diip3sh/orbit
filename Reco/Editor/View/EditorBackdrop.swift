//
//  EditorBackdrop.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import AppKit
import SwiftUI

/// The desktop behind the window, blurred, as macOS draws it behind sidebars. With Reduce
/// Transparency on, macOS draws it solid.
struct EditorBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
