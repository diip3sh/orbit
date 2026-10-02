//
//  TransportBar.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// Play/pause, frame stepping, the playhead's time, cutting and zooming, floating on glass under
/// the preview. Space plays and pauses, ← and → step a frame, S splits at the playhead, Z adds a
/// zoom there, ⌫ removes the selection and ⇧⌘C copies the frame.
struct TransportBar: View {
    let viewModel: EditorViewModel

    var body: some View {
        let playback = viewModel.playback
        let duration = viewModel.timeMap.outputDuration

        EditorGlassGroup {
            HStack {
                HStack(spacing: EditorTheme.tightSpacing) {
                    Button("Split at Playhead", systemImage: "scissors") {
                        viewModel.split()
                    }
                    .keyboardShortcut("s", modifiers: [])
                    .help("Split at the playhead (S)")

                    Button("Add Zoom", systemImage: "plus.magnifyingglass") {
                        viewModel.addZoom()
                    }
                    .keyboardShortcut("z", modifiers: [])
                    .help("Add a zoom at the playhead (Z)")
                    .disabled(!viewModel.canAddZoom)

                    let deletesZoom = viewModel.selectedZoom != nil
                    Button(deletesZoom ? "Delete Zoom" : "Cut Selection", systemImage: "trash") {
                        viewModel.deleteSelection()
                    }
                    .keyboardShortcut(.delete, modifiers: [])
                    .help(deletesZoom ? "Delete the selected zoom (⌫)" : "Cut the selected part (⌫)")
                    .disabled(!viewModel.canDeleteSelection)

                    Button("Copy Frame", systemImage: "photo.on.rectangle") {
                        Task {
                            await viewModel.copyFrame()
                        }
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .help("Copy the frame at the playhead (⇧⌘C)")
                }
                .padding(EditorTheme.tightSpacing)
                .editorGlass(in: .capsule)

                Spacer()

                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playback.isPlaying)) { _ in
                    HStack(spacing: EditorTheme.tightSpacing) {
                        Text(Self.format(playback.currentTime))
                        Text("/ \(Self.format(duration))")
                            .foregroundStyle(EditorTheme.dim)
                    }
                    .font(.callout)
                    .monospaced()
                }
                .padding(.horizontal, EditorTheme.spacing)
                .frame(height: 38)
                .editorGlass(in: .capsule)
            }
            .overlay {
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
                .padding(EditorTheme.tightSpacing)
                .editorGlass(in: .capsule)
            }
        }
        .buttonStyle(.editorIcon)
    }

    private static func format(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
