//
//  EditorInspector.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The canvas, the selected zoom, style controls for what's drawn from input telemetry (cursor,
/// click highlights and keystrokes), and the audio tracks' volumes.
struct EditorInspector: View {
    @Bindable var viewModel: EditorViewModel

    @State private var choosesBackgroundImage = false

    var body: some View {
        let telemetry = viewModel.source?.telemetry

        Form {
            Section {
                Picker("Aspect Ratio", selection: $viewModel.canvas.aspect) {
                    Text("Original").tag(CanvasStyle.Aspect.source)
                    Text("16:9").tag(CanvasStyle.Aspect.landscape)
                    Text("9:16").tag(CanvasStyle.Aspect.portrait)
                    Text("1:1").tag(CanvasStyle.Aspect.square)
                    Text("4:3").tag(CanvasStyle.Aspect.standard)
                }
                Picker("Background", selection: $viewModel.canvas.background) {
                    Text("Gradient").tag(CanvasStyle.Background.gradient)
                    Text("Color").tag(CanvasStyle.Background.color)
                    Text("Image").tag(CanvasStyle.Background.image)
                    Text("Transparent").tag(CanvasStyle.Background.transparent)
                }
                switch viewModel.canvas.background {
                case .gradient:
                    ColorPicker("Start", selection: $viewModel.canvas.gradientStart.cgColor, supportsOpacity: false)
                    ColorPicker("End", selection: $viewModel.canvas.gradientEnd.cgColor, supportsOpacity: false)
                case .color:
                    ColorPicker("Color", selection: $viewModel.canvas.color.cgColor, supportsOpacity: false)
                case .image:
                    Button("Choose Image…") {
                        choosesBackgroundImage = true
                    }
                case .transparent:
                    EmptyView()
                }
                LabeledContent("Padding") {
                    Slider(value: $viewModel.canvas.padding, in: 0...0.25)
                }
                LabeledContent("Corners") {
                    Slider(value: $viewModel.canvas.cornerRadius, in: 0...0.05)
                }
                LabeledContent("Shadow") {
                    Slider(value: $viewModel.canvas.shadow, in: 0...1)
                }
            } header: {
                Text("Canvas")
            } footer: {
                if viewModel.canvas.background == .transparent {
                    Text("Only ProRes 4444 exports keep the background transparent; other formats make it black.")
                }
            }
            .fileImporter(isPresented: $choosesBackgroundImage, allowedContentTypes: [.image]) { result in
                if case .success(let url) = result {
                    viewModel.setBackgroundImage(url)
                }
            }

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
