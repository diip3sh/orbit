//
//  CountdownView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The remaining seconds on a disc of the capture toolbar's surface, floating over the screen. It grows in from its centre;
/// it has no exit of its own, since the panel must be gone before the first recorded frame
/// (`CountdownOverlay.dismiss()` removes it at once).
struct CountdownView: View {
    let countdown: RecordingCountdown

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    var body: some View {
        ZStack {
            if let remaining = countdown.remaining {
                Text(remaining, format: .number)
                    // Sized to sit in the fixed 150 pt disc; macOS has no Dynamic Type to follow
                    .font(Font(Typeface.sans.font(size: 80, weight: Font.Weight.bold.axisValue) as CTFont))
                    .monospacedDigit()
                    .contentTransition(reducesMotion ? .opacity : .numericText(countsDown: true))
                    .foregroundStyle(EditorTheme.ink)
                    .frame(width: 150, height: 150)
                    // The 200 pt panel leaves 25 pt around the disc, room for the floating shadow
                    .editorSurface(in: Circle(), floats: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: countdown.remaining)
        .panelPresentation(isPresented: true, anchor: .center)
    }
}
