//
//  CountdownView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The remaining seconds as a large number floating over the screen.
struct CountdownView: View {
    let countdown: RecordingCountdown

    var body: some View {
        ZStack {
            if let remaining = countdown.remaining {
                Text(remaining, format: .number)
                    // Sized to fill the fixed 200 pt panel; macOS has no Dynamic Type to follow
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    // No backdrop, so a shadow keeps it readable over light and dark content
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy, value: countdown.remaining)
    }
}
