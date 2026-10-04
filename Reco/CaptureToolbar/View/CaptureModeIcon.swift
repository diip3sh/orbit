//
//  CaptureModeIcon.swift
//  Reco
//

import SwiftUI

/// A mode's picture, as in the system's Screenshot toolbar: recording modes carry a record badge in
/// the bottom-right corner, cut out of the picture under it.
struct CaptureModeIcon: View {
    let mode: CaptureToolbarMode
    /// What the badge is cut out of: the highlight when the mode is chosen, the bar otherwise
    var ground = CaptureToolbarView.ground

    private var resource: ImageResource {
        switch mode {
        case .captureScreen, .recordScreen: .toolbarScreen
        case .captureWindow, .recordWindow: .toolbarWindow
        case .captureArea, .recordArea: .toolbarArea
        }
    }

    var body: some View {
        ToolbarIcon(resource)
            .overlay(alignment: .bottomTrailing) {
                if mode.records {
                    Circle()
                        .strokeBorder(lineWidth: 1.5)
                        .overlay(Circle().padding(3))
                        .frame(width: 10, height: 10)
                        .padding(1.5)
                        .background(ground, in: .circle)
                        .offset(x: 4, y: 3)
                }
            }
    }
}
