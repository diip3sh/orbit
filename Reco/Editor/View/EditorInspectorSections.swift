//
//  EditorInspectorSections.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The editor's right column: the tab bar, a notice when the telemetry is missing, then the chosen tab's
/// sections. Selecting a zoom on the timeline turns to Motion, where its settings are.
struct EditorInspector: View {
    @Bindable var viewModel: EditorViewModel
    @Binding var tab: InspectorTab

    /// The width it opens at, picked by hand on 2026-10-07 in a 1533 pt window: room for five aspect tiles
    /// with their names and the sliders' values. The export page's options use the same column.
    static let idealWidth: CGFloat = 380

    var body: some View {
        let trackNames = viewModel.source?.audioTrackNames ?? []

        VStack(spacing: 0) {
            InspectorTabBar(selection: $tab) { $0.isAvailable(hasAudio: !trackNames.isEmpty) }
                .padding([.horizontal, .top])

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

                    switch tab {
                    case .background:
                        CanvasInspectorSection(viewModel: viewModel)
                    case .audio:
                        AudioInspectorSection(viewModel: viewModel, trackNames: trackNames)
                    case .cursor:
                        CursorInspectorSection(viewModel: viewModel)
                        ClicksInspectorSection(viewModel: viewModel)
                    case .keyboard:
                        KeystrokesInspectorSection(viewModel: viewModel)
                    case .motion:
                        MotionInspectorSection(viewModel: viewModel)
                        ZoomInspectorSection(viewModel: viewModel)
                    case .camera, .caption:
                        EmptyView()
                    }
                }
                .toggleStyle(.inspector)
                .controlSize(.small)
            }
            .scrollIndicators(.never)
            // Each tab opens at its top
            .id(tab)
            .transition(.opacity)
        }
        .editorMotion(EditorTheme.quickMotion, value: tab)
        .onChange(of: viewModel.selection) { _, selection in
            if case .zoom = selection {
                tab = .motion
            }
        }
    }
}

/// The selected zoom's scale and focus, and regenerating the automatic zooms.
struct ZoomInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry
        let isWebTake = telemetry?.capture.kind == .web

        InspectorSection("Zoom") {
            if let zoom = Binding(unwrapping: $viewModel.selectedZoom) {
                InspectorSlider("Scale", value: zoom.scale, in: 1.25...4) {
                    Text("\($0, format: .number.precision(.fractionLength(0...2)))×")
                }
                InspectorField("Focus") {
                    SegmentedChoice(selection: zoom.followsCursor, options: [(true, "Follow Cursor"), (false, "Fixed")])
                    .disabled(telemetry == nil)
                }
                if let center = Binding(unwrapping: zoom.fixedCenter), let videoSize = viewModel.source?.naturalSize {
                    ZoomFocusPad(
                        image: viewModel.thumbnail(at: zoom.wrappedValue.range.lowerBound),
                        videoSize: videoSize,
                        scale: zoom.wrappedValue.scale,
                        center: center
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
    }
}

/// How the camera and the drawn cursor move.
struct MotionInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry
        let cursorIsRecorded = telemetry?.capture.cursorInVideo != false

        InspectorSection("Motion") {
            InspectorField("Zoom") {
                SegmentedChoice(selection: $viewModel.zoomMotion, options: [(.mellow, "Mellow"), (.smooth, "Smooth"), (.fast, "Fast")])
            }
            InspectorField("Cursor") {
                SegmentedChoice(selection: $viewModel.cursor.smoothing, options: [(.mellow, "Mellow"), (.smooth, "Smooth"), (.fast, "Fast")])
                    .disabled(cursorIsRecorded)
                    // Text in ink doesn't dim by itself when disabled
                    .opacity(cursorIsRecorded ? 0.4 : 1)
            }
        } footer: {
            if telemetry?.capture.cursorInVideo == true {
                Text("The cursor is part of this recording's video, so it moves as it was recorded.")
            }
        }
    }
}

/// The drawn cursor's visibility, size and animations.
struct CursorInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry

        InspectorSection("Cursor") {
            Toggle("Show Cursor", isOn: $viewModel.cursor.isEnabled)
            InspectorSlider("Size", value: $viewModel.cursor.size, in: 0.5...3) {
                Text("\($0, format: .number.precision(.fractionLength(1)))×")
            }
            Toggle("Shrink on Click", isOn: $viewModel.cursor.animatesClicks)
            Toggle("Hide When Idle", isOn: $viewModel.cursor.hidesWhenIdle)
        } footer: {
            if telemetry?.capture.cursorInVideo == true {
                Text("""
                    This recording shows the system cursor, so it can't be changed. For new recordings, \
                    turn off Keep System Cursor in Video in Settings → Video → Advanced.
                    """)
            }
        }
        .disabled(telemetry?.capture.cursorInVideo != false)
    }
}

/// The click highlights' color, size, duration and buttons.
struct ClicksInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
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
                SegmentedChoice(selection: $viewModel.clickHighlights.buttons, options: [(.all, "All"), (.left, "Left Only"), (.right, "Right Only")])
            }
        }
        .disabled(viewModel.source?.telemetry == nil)
    }
}

/// Which keystrokes are shown.
struct KeystrokesInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry

        InspectorSection("Keystrokes") {
            Toggle("Show Keystrokes", isOn: $viewModel.keystrokes.isEnabled)
            Toggle("Show All Keys", isOn: $viewModel.keystrokes.showsAllKeys)
        } footer: {
            if telemetry?.keystrokesAvailable == false {
                Text("Keystrokes weren't recorded: Orbit didn't have Input Monitoring access.")
            } else if viewModel.keystrokes.showsAllKeys {
                Text("Everything typed is shown, passwords included.")
            } else {
                Text("Only shortcuts and special keys, like ⏎ and arrows, are shown.")
            }
        }
        .disabled(telemetry?.keystrokesAvailable != true)
    }
}

/// Each audio track's volume and mute.
struct AudioInspectorSection: View {
    @Bindable var viewModel: EditorViewModel
    let trackNames: [String]

    var body: some View {
        InspectorSection("Audio") {
            ForEach(trackNames.indices, id: \.self) { index in
                AudioTrackRow(name: trackNames[index], settings: $viewModel.audio[track: index])
            }
        }
    }
}
