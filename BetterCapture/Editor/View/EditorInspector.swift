//
//  EditorInspector.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The selected zoom, style controls for what's drawn from input telemetry (cursor, click
/// highlights and keystrokes), and the audio tracks' volumes.
struct EditorInspector: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry

        Form {
            Section {
                if let zoom = Binding($viewModel.selectedZoom) {
                    LabeledContent("Scale") {
                        Slider(value: zoom.scale, in: 1.25...4)
                    }
                    Picker("Focus", selection: zoom.followsCursor) {
                        Text("Follow Cursor").tag(true)
                        Text("Fixed").tag(false)
                    }
                    .disabled(telemetry == nil)
                    if let center = Binding(zoom.fixedCenter), let videoSize = viewModel.source?.naturalSize {
                        ZoomFocusPad(
                            image: viewModel.thumbnail(at: zoom.wrappedValue.range.lowerBound),
                            videoSize: videoSize,
                            scale: zoom.wrappedValue.scale,
                            center: center
                        )
                    }
                } else {
                    Text("Select a zoom on the timeline to change it.")
                        .foregroundStyle(.secondary)
                }
                Button("Regenerate Automatic Zooms") {
                    viewModel.regenerateZooms()
                }
                .disabled(telemetry == nil)
            } header: {
                Text("Zoom")
            } footer: {
                if viewModel.zoomsLookSoft {
                    Text("""
                        Zoomed parts look soft: this recording has fewer than 2 pixels per screen point. \
                        On a Retina display, turn on Native Resolution in Settings → Video → Advanced.
                        """)
                }
            }

            Section {
                Toggle("Show Cursor", isOn: $viewModel.cursor.isEnabled)
                LabeledContent("Size") {
                    Slider(value: $viewModel.cursor.size, in: 0.5...3)
                }
                Picker("Movement", selection: $viewModel.cursor.smoothing) {
                    Text("Mellow").tag(CursorStyle.Smoothing.mellow)
                    Text("Smooth").tag(CursorStyle.Smoothing.smooth)
                    Text("Fast").tag(CursorStyle.Smoothing.fast)
                }
                Toggle("Shrink on Click", isOn: $viewModel.cursor.animatesClicks)
                Toggle("Hide When Idle", isOn: $viewModel.cursor.hidesWhenIdle)
            } header: {
                Text("Cursor")
            } footer: {
                if telemetry?.capture.cursorInVideo == true {
                    Text("""
                        This recording shows the system cursor, so it can't be changed. For new recordings, \
                        turn off Keep System Cursor in Video in Settings → Video → Advanced.
                        """)
                }
            }
            .disabled(telemetry?.capture.cursorInVideo != false)

            Section {
                Toggle("Highlight Clicks", isOn: $viewModel.clickHighlights.isEnabled)
                ColorPicker("Color", selection: $viewModel.clickHighlights.color.cgColor)
                LabeledContent("Size") {
                    Slider(value: $viewModel.clickHighlights.size, in: 16...120)
                }
                LabeledContent("Duration") {
                    Slider(value: $viewModel.clickHighlights.duration, in: 0.2...1.5)
                }
                Picker("Buttons", selection: $viewModel.clickHighlights.buttons) {
                    Text("All").tag(ClickHighlightStyle.Buttons.all)
                    Text("Left Only").tag(ClickHighlightStyle.Buttons.left)
                    Text("Right Only").tag(ClickHighlightStyle.Buttons.right)
                }
            } header: {
                Text("Clicks")
            } footer: {
                if let reason = viewModel.source?.telemetryError {
                    Text(reason.localizedDescription)
                }
            }
            .disabled(telemetry == nil)

            Section {
                Toggle("Show Keystrokes", isOn: $viewModel.keystrokes.isEnabled)
                Toggle("Show All Keys", isOn: $viewModel.keystrokes.showsAllKeys)
            } header: {
                Text("Keystrokes")
            } footer: {
                if telemetry?.keystrokesAvailable == false {
                    Text("Keystrokes weren't recorded: BetterCapture didn't have Input Monitoring access.")
                } else if viewModel.keystrokes.showsAllKeys {
                    Text("Everything typed is shown, passwords included.")
                } else {
                    Text("Only shortcuts and special keys, like ⏎ and arrows, are shown.")
                }
            }
            .disabled(telemetry?.keystrokesAvailable != true)

            if let names = viewModel.source?.audioTrackNames, !names.isEmpty {
                Section("Audio") {
                    ForEach(names.indices, id: \.self) { index in
                        let isMuted = viewModel.audio[track: index].isMuted
                        LabeledContent(names[index]) {
                            HStack {
                                Slider(value: $viewModel.audio[track: index].volume, in: 0...1)
                                    .disabled(isMuted)
                                Toggle("Mute", systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", isOn: $viewModel.audio[track: index].isMuted)
                                    .toggleStyle(.button)
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
