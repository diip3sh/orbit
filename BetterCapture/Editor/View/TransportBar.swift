//
//  TransportBar.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// Play/pause, frame stepping and the playhead's time. Space plays and pauses, ← and → step a frame.
struct TransportBar: View {
    let playback: PlaybackController
    let duration: Double

    var body: some View {
        HStack {
            Button("Previous Frame", systemImage: "backward.frame.fill") {
                playback.step(by: -1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button(playback.isPlaying ? "Pause" : "Play", systemImage: playback.isPlaying ? "pause.fill" : "play.fill") {
                playback.togglePlay()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("Next Frame", systemImage: "forward.frame.fill") {
                playback.step(by: 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playback.isPlaying)) { _ in
                Text("\(Self.format(playback.currentTime)) / \(Self.format(duration))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .padding()
    }

    private static func format(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
