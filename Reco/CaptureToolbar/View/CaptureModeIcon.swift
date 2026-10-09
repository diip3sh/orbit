//
//  CaptureModeIcon.swift
//  Reco
//

import SwiftUI

/// A mode's picture, as in the system's Screenshot toolbar: recording modes carry a record badge in
/// the bottom-right corner, cut out of the picture under it. Cut, not painted over in a colour: the chosen
/// mode's highlight is glass, which no solid colour matches.
struct CaptureModeIcon: View {
    let mode: CaptureToolbarMode

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
                        .background { Circle().blendMode(.destinationOut) }
                        .offset(x: 4, y: 3)
                }
            }
            // Keeps the cut inside the icon, so what is behind the button shows through it
            .compositingGroup()
    }
}
