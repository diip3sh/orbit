//
//  TransportBar.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// Cutting, speed and zooming, play/pause and frame stepping, and the playhead's time, in the timeline's
/// header. Space plays and pauses, ← and → step a frame, S splits at the playhead, Z adds a
/// zoom there, M a mask, ⌫ removes the selection and ⇧⌘C copies the frame.
struct TransportBar: View {
    @Bindable var viewModel: EditorViewModel

    /// Shows a check for a moment after Copy Frame, since nothing else on screen changes.
    @State private var copiedFrame = false

    var body: some View {
        let playback = viewModel.playback
        let duration = viewModel.timeMap.outputDuration

        // Three groups side by side, never stacked: an overlay put Play over the tools in a
        // narrow window, and the time wrapped onto two lines
        HStack(spacing: EditorTheme.smallSpacing) {
            HStack(spacing: EditorTheme.tightSpacing) {
                Button("Split at Playhead", systemImage: "scissors") {
                    viewModel.split()
                }
                .keyboardShortcut("s", modifiers: [])
                .help("Split at the playhead (S)")

                Menu {
                    Picker("Speed", selection: $viewModel.selectedSpeed) {
                        ForEach(SpeedRange.rates, id: \.self) { rate in
                            Text(SpeedRange.label(for: rate)).tag(rate)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Speed", systemImage: "gauge.with.dots.needle.67percent")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .fixedSize()
                .help(viewModel.canChangeSpeed ? "Speed of the selected part" : "Select a part to change its speed")
                .disabled(!viewModel.canChangeSpeed)

                Button("Add Zoom", systemImage: "plus.magnifyingglass") {
                    viewModel.addZoom()
                }
                .keyboardShortcut("z", modifiers: [])
                .help("Add a zoom at the playhead (Z)")
                .disabled(!viewModel.canAddZoom)

                Button("Add Mask", systemImage: "eye.slash") {
                    viewModel.addMask()
                }
                .keyboardShortcut("m", modifiers: [])
                .help("Hide part of the frame from the playhead (M)")
                .disabled(!viewModel.canAddMask)

                let deleted = deletedName
                Button(deleted.map { "Delete \($0)" } ?? "Cut Selection", systemImage: "trash") {
                    viewModel.deleteSelection()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .help(deleted.map { "Delete the selected \($0.lowercased()) (⌫)" } ?? "Cut the selected part (⌫)")
                .disabled(!viewModel.canDeleteSelection)

                Button(copiedFrame ? "Copied" : "Copy Frame", systemImage: copiedFrame ? "checkmark" : "photo.on.rectangle") {
                    Task {
                        guard await viewModel.copyFrame() else { return }
                        copiedFrame = true
                        try? await Task.sleep(for: .seconds(1.5))
                        copiedFrame = false
                    }
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .contentTransition(.symbolEffect(.replace))
                .help("Copy the frame at the playhead as an image (⇧⌘C)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
            .fixedSize()

            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playback.isPlaying)) { _ in
                HStack(spacing: EditorTheme.tightSpacing) {
                    Text(Self.format(playback.currentTime))
                    Text("/ \(Self.format(duration))")
                        .foregroundStyle(EditorTheme.dim)
                }
                .font(.callout)
                .monospaced()
                .lineLimit(1)
                .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.editorIcon)
    }

    /// What ⌫ deletes when it isn't a part of the recording.
    private var deletedName: String? {
        switch viewModel.selection {
        case .zoom: "Zoom"
        case .mask: "Mask"
        case .segment, nil: nil
        }
    }

    private static func format(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
