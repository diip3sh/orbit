//
//  EditorInspector.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The canvas, the selected zoom, style controls for what's drawn from input telemetry (cursor,
/// click highlights and keystrokes), and the audio tracks' volumes.
struct EditorInspector: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry
        let isWebTake = telemetry?.capture.kind == .web

        ScrollView {
            VStack(spacing: 0) {
                if let reason = viewModel.source?.telemetryError {
                    Label(reason.localizedDescription, systemImage: "info.circle")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(EditorTheme.mediumSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.primary.opacity(0.06), in: .rect(cornerRadius: 8))
                        .padding([.horizontal, .top])
                }

                CanvasInspectorSection(viewModel: viewModel)

                InspectorSection("Zoom") {
                    if let zoom = Binding($viewModel.selectedZoom) {
                        InspectorSlider("Scale", value: zoom.scale, in: 1.25...4) {
                            Text("\($0, format: .number.precision(.fractionLength(0...2)))×")
                        }
                        InspectorField("Focus") {
                            EditorSegmentedPicker(selection: zoom.followsCursor, options: [
                                (true, "Follow Cursor"),
                                (false, "Fixed")
                            ])
                            .disabled(telemetry == nil)
                        }
                        if let center = zoom.wrappedValue.fixedCenter, let videoSize = viewModel.source?.naturalSize {
                            ZoomFocusPad(
                                image: viewModel.thumbnail(at: zoom.wrappedValue.range.lowerBound),
                                videoSize: videoSize,
                                scale: zoom.wrappedValue.scale,
                                // Not `Binding(zoom.fixedCenter)`: the pad fades out after the focus is
                                // gone, and an unwrapped binding traps on its next update
                                center: Binding { viewModel.selectedZoom?.fixedCenter ?? center } set: { viewModel.selectedZoom?.fixedCenter = $0 }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    } else {
                        Label("Select a zoom on the timeline to change it.", systemImage: "cursorarrow.click")
                            .foregroundStyle(EditorTheme.dim)
                    }
                    Button {
                        viewModel.regenerateZooms()
                    } label: {
                        Label("Regenerate Automatic Zooms", systemImage: "wand.and.sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.editorGhost)
                    .disabled(telemetry == nil)
                } footer: {
                    if telemetry?.clicks.isEmpty == true {
                        if isWebTake {
                            Text("""
                                This take has no clicks, so automatic zooms come only from where the cursor rested. \
                                Press Z to add one at the playhead.
                                """)
                        } else {
                            Text("""
                                No clicks were recorded (they need Input Monitoring), so automatic zooms come only from \
                                where the cursor rested or circled. Press Z to add one at the playhead.
                                """)
                        }
                    }
                    if viewModel.zoomsLookSoft {
                        if isWebTake {
                            Text("Zoomed parts look soft: this take was rendered at 1×. Render it at 2× in the Web Recording window.")
                        } else {
                            Text("""
                                Zoomed parts look soft: this recording has fewer than 2 pixels per screen point. \
                                On a Retina display, turn on Native Resolution in Settings → Video → Advanced.
                                """)
                        }
                    }
                }
                .editorMotion(value: viewModel.selectedZoom)

                InspectorSection("Cursor") {
                    Toggle("Show Cursor", isOn: $viewModel.cursor.isEnabled)
                    InspectorSlider("Size", value: $viewModel.cursor.size, in: 0.5...3) {
                        Text("\($0, format: .number.precision(.fractionLength(1)))×")
                    }
                    InspectorField("Movement") {
                        EditorSegmentedPicker(selection: $viewModel.cursor.smoothing, options: [
                            (CursorStyle.Smoothing.mellow, "Mellow"),
                            (CursorStyle.Smoothing.smooth, "Smooth"),
                            (CursorStyle.Smoothing.fast, "Fast")
                        ])
                    }
                    .disabled(isWebTake)
                    Toggle("Shrink on Click", isOn: $viewModel.cursor.animatesClicks)
                    Toggle("Hide When Idle", isOn: $viewModel.cursor.hidesWhenIdle)
                } footer: {
                    if isWebTake {
                        Text("A web take's cursor moves as scripted, so it's drawn without smoothing, in step with the page.")
                    }
                    if telemetry?.capture.cursorInVideo == true {
                        Text("""
                            This recording shows the system cursor, so it can't be changed. For new recordings, \
                            turn off Keep System Cursor in Video in Settings → Video → Advanced.
                            """)
                    }
                }
                .disabled(telemetry?.capture.cursorInVideo != false)

                InspectorSection("Clicks") {
                    Toggle("Highlight Clicks", isOn: $viewModel.clickHighlights.isEnabled)
                    ColorPicker("Color", selection: $viewModel.clickHighlights.color.cgColor)
                    InspectorSlider("Size", value: $viewModel.clickHighlights.size, in: 16...120) {
                        Text("\($0, format: .number.precision(.fractionLength(0))) pt")
                    }
                    InspectorSlider("Duration", value: $viewModel.clickHighlights.duration, in: 0.2...1.5) {
                        Text("\($0, format: .number.precision(.fractionLength(1))) s")
                    }
                    InspectorField("Buttons") {
                        EditorSegmentedPicker(selection: $viewModel.clickHighlights.buttons, options: [
                            (ClickHighlightStyle.Buttons.all, "All"),
                            (ClickHighlightStyle.Buttons.left, "Left Only"),
                            (ClickHighlightStyle.Buttons.right, "Right Only")
                        ])
                    }
                }
                .disabled(telemetry == nil)

                InspectorSection("Keystrokes") {
                    Toggle("Show Keystrokes", isOn: $viewModel.keystrokes.isEnabled)
                    Toggle("Show All Keys", isOn: $viewModel.keystrokes.showsAllKeys)
                } footer: {
                    if telemetry?.keystrokesAvailable == false {
                        Text("Keystrokes weren't recorded: Reco didn't have Input Monitoring access.")
                    } else if viewModel.keystrokes.showsAllKeys {
                        Text("Everything typed is shown, passwords included.")
                    } else {
                        Text("Only shortcuts and special keys, like ⏎ and arrows, are shown.")
                    }
                }
                .disabled(telemetry?.keystrokesAvailable != true)

                if let names = viewModel.source?.audioTrackNames, !names.isEmpty {
                    InspectorSection("Audio") {
                        ForEach(names.indices, id: \.self) { index in
                            AudioTrackRow(name: names[index], settings: $viewModel.audio[track: index])
                        }
                    }
                }
            }
            .toggleStyle(.inspector)
            .controlSize(.small)
        }
        .scrollIndicators(.never)
        // The controls fade out under the switch and into the panel's bottom edge
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: EditorTheme.spacing)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: EditorTheme.largeSpacing + EditorTheme.smallSpacing)
            }
        }
    }
}
