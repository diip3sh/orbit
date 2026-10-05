//
//  CountdownView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The remaining seconds on a disc of the capture toolbar's dark glass, floating over the screen. It grows in from its centre;
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
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(reducesMotion ? .opacity : .numericText(countsDown: true))
                    .foregroundStyle(.white)
                    // 150 pt across with the surface's 4 pt inset
                    .frame(width: 142, height: 142)
                    // Dark glass, as the toolbar's, reads the same over light and dark content
                    .captureToolbarPill(in: Circle(), isInteractive: false)
            }
        }
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reducesMotion ? EditorTheme.fadeMotion : EditorTheme.motion, value: countdown.remaining)
        .panelPresentation(isPresented: true, anchor: .center)
    }
}
