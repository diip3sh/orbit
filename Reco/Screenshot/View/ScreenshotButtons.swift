//
//  ScreenshotButtons.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Capture Area / Window / Screen rows for the menu bar popover
struct ScreenshotButtons: View {
    let controller: ScreenshotController
    let recorder: RecorderViewModel
    @Environment(\.dismiss) private var dismiss

    private var isDisabled: Bool {
        !controller.canCapture(alongside: recorder)
    }

    var body: some View {
        // Each closes the popover first so it never lands in the screenshot
        MenuBarActionButton(title: "Capture Area", systemImage: "rectangle.dashed", isDisabled: isDisabled) {
            dismiss()
            Task { await controller.captureArea() }
        }
        MenuBarActionButton(title: "Capture Window", systemImage: "macwindow", isDisabled: isDisabled) {
            dismiss()
            Task { await controller.captureWindow() }
        }
        MenuBarActionButton(title: "Capture Screen", systemImage: "display", isDisabled: isDisabled) {
            dismiss()
            Task { await controller.captureScreen() }
        }
    }
}
