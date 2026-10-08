//
//  AudioTrackRow.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// An audio track's volume and mute button.
struct AudioTrackRow: View {
    let name: String
    @Binding var settings: AudioMixSettings.Track

    var body: some View {
        VStack(spacing: EditorTheme.tightSpacing) {
            HStack {
                Text(name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(settings.isMuted ? 0 : settings.volume, format: .percent.precision(.fractionLength(0)))
                    .font(.theme(.caption).monospacedDigit())
                    .foregroundStyle(EditorTheme.dim)
                Toggle(
                    "Mute \(name)",
                    systemImage: settings.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    isOn: $settings.isMuted
                )
                .toggleStyle(.button)
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
            }
            TickSlider(
                title: "\(name) Volume",
                value: $settings.volume,
                range: 0...1,
                valueLabel: Text(settings.volume, format: .percent.precision(.fractionLength(0)))
            )
            .disabled(settings.isMuted)
        }
    }
}
