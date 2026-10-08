//
//  EditorInspectorSections.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The editor's right column: the tab bar, a notice when the telemetry is missing, then the chosen tab's
/// sections. Selecting a zoom on the timeline turns to Motion, a mask to Background, where their settings are.
struct EditorInspector: View {
    @Bindable var viewModel: EditorViewModel
    @Binding var tab: InspectorTab

    /// The width it opens at, picked by hand on 2026-10-07 in a 1533 pt window: room for five aspect tiles
    /// with their names and the sliders' values. The export page's options use the same column.
    static let idealWidth: CGFloat = 380

    var body: some View {
        let trackNames = viewModel.source?.audioTrackNames ?? []

        VStack(spacing: 0) {
            InspectorTabBar(selection: $tab) { $0.isAvailable }
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
                        MaskInspectorSection(viewModel: viewModel)
                    case .audio:
                        if !trackNames.isEmpty {
                            AudioInspectorSection(viewModel: viewModel, trackNames: trackNames)
                        }
                        BackgroundAudioInspectorSection(viewModel: viewModel)
                    case .cursor:
                        CursorInspectorSection(viewModel: viewModel)
                        ClicksInspectorSection(viewModel: viewModel)
                    case .keyboard:
                        KeystrokesInspectorSection(viewModel: viewModel)
                    case .motion:
                        MotionInspectorSection(viewModel: viewModel)
                        ZoomInspectorSection(viewModel: viewModel)
                        SpeedInspectorSection(viewModel: viewModel)
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
            switch selection {
            case .zoom: tab = .motion
            case .mask: tab = .background
            case .segment, nil: break
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
                if let center = Binding(unwrapping: zoom.fixedCenter), let videoSize = viewModel.videoSize {
                    ZoomFocusPad(
                        image: viewModel.croppedThumbnail(at: zoom.wrappedValue.range.lowerBound),
                        videoSize: videoSize,
                        scale: zoom.wrappedValue.scale,
                        baseView: viewModel.baseView,
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
            InspectorSlider("Motion Blur", value: $viewModel.motionBlur, in: 0...1, defaultValue: 0) {
                $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
            }
            InspectorField("Cursor") {
                SegmentedChoice(selection: $viewModel.cursor.smoothing, options: [(.mellow, "Mellow"), (.smooth, "Smooth"), (.fast, "Fast"), (.off, "None")])
                    .disabled(cursorIsRecorded)
                    // Text in ink doesn't dim by itself when disabled
                    .opacity(cursorIsRecorded ? 0.4 : 1)
            }
        } footer: {
            if viewModel.motionBlur > 0, viewModel.project.zooms.isEmpty {
                Text("Blurs the camera's moves; frames without them stay sharp.")
            }
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
        let isRecordedStyle = viewModel.cursor.appearance == .recorded

        InspectorSection("Cursor") {
            Toggle("Show Cursor", isOn: $viewModel.cursor.isEnabled)
            InspectorField("Style") {
                TilePicker(selection: $viewModel.cursor.appearance, values: CursorStyle.Appearance.allCases) { appearance in
                    switch appearance {
                    case .recorded: "macOS"
                    case .white: "White"
                    case .dot: "Dot"
                    }
                } picture: { appearance in
                    CursorStylePicture(appearance: appearance)
                }
            }
            InspectorSlider("Size", value: $viewModel.cursor.size, in: 0.5...3, defaultValue: 1) {
                Text("\($0, format: .number.precision(.fractionLength(1)))×")
            }
            Toggle("Always Use Pointer", isOn: $viewModel.cursor.alwaysUsesArrow)
                .disabled(!isRecordedStyle)
                .opacity(isRecordedStyle ? 1 : 0.4)
            Toggle("Shrink on Click", isOn: $viewModel.cursor.animatesClicks)
            Toggle("Hide When Idle", isOn: $viewModel.cursor.hidesWhenIdle)
            Toggle("Tilt While Moving", isOn: $viewModel.cursor.tilts)
            Toggle("Loop Position", isOn: $viewModel.cursor.loops)
            InspectorSlider("Stop Before End", value: $viewModel.cursor.stopDuration, in: 0...3, defaultValue: 0) {
                $0 == 0 ? Text("Off") : Text("\($0, format: .number.precision(.fractionLength(1))) s")
            }
        } footer: {
            if viewModel.cursor.loops {
                Text("In the last second the cursor glides back to where it started, so the video loops.")
            }
            if viewModel.cursor.stopDuration > 0 {
                Text("The cursor holds still at the end, so reaching for Stop doesn't show.")
            }
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

/// The click highlights' effect, color, size, duration and buttons, and the click sound.
struct ClicksInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let hasEffect = viewModel.clickHighlights.effect != .off

        InspectorSection("Clicks") {
            InspectorField("Effect") {
                TilePicker(selection: $viewModel.clickHighlights.effect, values: ClickHighlightStyle.Effect.allCases) { effect in
                    switch effect {
                    case .off: "None"
                    case .circle: "Circle"
                    case .ripple: "Ripple"
                    }
                } picture: { effect in
                    ClickEffectPicture(effect: effect)
                }
            }
            // Dimmed rather than hidden, so the column doesn't jump
            Group {
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
            .disabled(!hasEffect)
            .opacity(hasEffect ? 1 : 0.4)
            InspectorSlider("Click Sound", value: $viewModel.audio.clickVolume, in: 0...1) {
                $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
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

/// The music looped under the whole video, with its volume and mute, or a button to choose a file.
struct BackgroundAudioInspectorSection: View {
    @Bindable var viewModel: EditorViewModel
    @State private var choosesFile = false

    var body: some View {
        InspectorSection("Background Audio") {
            Group {
                if let background = Binding(unwrapping: $viewModel.audio.background) {
                    AudioTrackRow(name: background.wrappedValue.name, settings: background.track)
                    Button {
                        viewModel.removeBackgroundAudio()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    Button {
                        choosesFile = true
                    } label: {
                        Label("Add Background Audio…", systemImage: "music.note")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .transition(.opacity)
        } footer: {
            Text("Loops under the whole video, fading in and out at the ends.")
        }
        .editorMotion(value: viewModel.audio.background != nil)
        .fileImporter(isPresented: $choosesFile, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result {
                viewModel.setBackgroundAudio(url)
            }
        }
    }
}
