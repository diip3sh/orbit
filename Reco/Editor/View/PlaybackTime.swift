//
//  PlaybackTime.swift
//  Reco
//

import SwiftUI

/// The playhead's time and the video's length, redrawn alone during playback.
struct PlaybackTime: View {
    let playback: PlaybackController
    let duration: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playback.isPlaying)) { _ in
            HStack(spacing: EditorTheme.tightSpacing) {
                Text(Self.format(playback.currentTime))
                Text("/ \(Self.format(duration))")
                    .foregroundStyle(EditorTheme.dim)
            }
            .font(.callout)
            .monospaced()
        }
    }

    private static func format(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
