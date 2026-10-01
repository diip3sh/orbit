//
//  WebPreviewView.swift
//  Reco
//

import AppKit
import SwiftUI

/// The live page, laid out at the script's viewport and shrunk to the space it's given.
struct WebPreviewView: NSViewRepresentable {
    let controller: WebPreviewController

    func makeNSView(context: Context) -> FittingView {
        FittingView(controller: controller)
    }

    func updateNSView(_ view: FittingView, context: Context) {
        view.needsLayout = true
    }

    /// Fills itself with the web view and zooms the page to fit its width.
    final class FittingView: NSView {
        private let controller: WebPreviewController

        init(controller: WebPreviewController) {
            self.controller = controller
            super.init(frame: .zero)
            addSubview(controller.webView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layout() {
            super.layout()
            controller.webView.frame = bounds
            controller.fit(width: bounds.width)
        }
    }
}
