//
//  PlaybackControls.swift
//  Reco
//

import SwiftUI

/// Previous frame, play/pause and next frame. Space plays and pauses, ← and → step a frame.
struct PlaybackControls: View {
    let playback: PlaybackController

    var body: some View {
        HStack(spacing: EditorTheme.tightSpacing) {
            Button("Previous Frame", systemImage: "backward.frame.fill") {
                playback.step(by: -1)
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button(playback.isPlaying ? "Pause" : "Play", systemImage: playback.isPlaying ? "pause.fill" : "play.fill") {
                playback.togglePlay()
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.editorProminentIcon)
            .contentTransition(.symbolEffect(.replace))

            Button("Next Frame", systemImage: "forward.frame.fill") {
                playback.step(by: 1)
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }
}
