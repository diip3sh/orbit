//
//  LiveIndicator.swift
//  Reco
//

import SwiftUI

/// "Live" over a streaming preview: a red dot and the word, static. The red is the only color
/// and means what it means on a recording light.
struct LiveIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
            Text("Live")
                .font(.caption)
        }
        .foregroundStyle(.white)
        // Legible over any picture
        .shadow(color: .black.opacity(0.5), radius: 2)
        .accessibilityElement(children: .combine)
    }
}
