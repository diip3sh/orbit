//
//  CursorInspectorSections.swift
//  Reco
//

import SwiftUI

/// The drawn cursor's visibility, size and animations.
struct CursorInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry
        let cursorIsRecorded = telemetry?.capture.cursorInVideo != false
        let isRecordedStyle = viewModel.cursor.appearance == .recorded

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Cursor")
            InspectorCard {
                VStack(spacing: 0) {
                    Toggle("Show Cursor", isOn: $viewModel.cursor.isEnabled)
                        .inspectorCardRow()
                    InspectorHairline()
                    VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                        Text("Style")
                        GlyphSegmentedPicker(
                            selection: $viewModel.cursor.appearance,
                            options: CursorStyle.Appearance.allCases.map { appearance in
                                switch appearance {
                                case .recorded: (appearance, "macOS")
                                case .white: (appearance, "White")
                                case .dot: (appearance, "Dot")
                                }
                            }
                        ) { appearance in
                            CursorStylePicture(appearance: appearance)
                        }
                    }
                    .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Always Use Pointer", isOn: $viewModel.cursor.alwaysUsesArrow)
                        .disabled(!isRecordedStyle)
                        // Text in ink doesn't dim by itself when disabled
                        .opacity(isRecordedStyle ? 1 : 0.4)
                        .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Shrink on Click", isOn: $viewModel.cursor.animatesClicks)
                        .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Hide When Idle", isOn: $viewModel.cursor.hidesWhenIdle)
                        .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Tilt While Moving", isOn: $viewModel.cursor.tilts)
                        .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Loop Position", isOn: $viewModel.cursor.loops)
                        .inspectorCardRow()
                }
                // Text in ink doesn't dim by itself when disabled
                .opacity(cursorIsRecorded ? 0.4 : 1)
            }
            SliderBar("Size", value: $viewModel.cursor.size, in: 0.5...3) {
                Text("\($0, format: .number.precision(.fractionLength(1)))×")
            }
            SliderBar("Stop Before End", value: $viewModel.cursor.stopDuration, in: 0...3) {
                $0 == 0 ? Text("Off") : Text("\($0, format: .number.precision(.fractionLength(1))) s")
            }
            if viewModel.cursor.loops {
                InspectorNote("In the last second the cursor glides back to where it started, so the video loops.")
            }
            if viewModel.cursor.stopDuration > 0 {
                InspectorNote("The cursor holds still at the end, so reaching for Stop doesn't show.")
            }
            if telemetry?.capture.cursorInVideo == true {
                InspectorNote("""
                    This recording shows the system cursor, so it can't be changed. For new recordings, \
                    turn off Keep System Cursor in Video in Settings → Video → Advanced.
                    """)
            }
        }
        .disabled(cursorIsRecorded)
    }
}

/// The click highlights' effect, color, size, duration and buttons, and the click sound.
struct ClicksInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let hasEffect = viewModel.clickHighlights.effect != .off

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Clicks")
            InspectorCard {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                        Text("Effect")
                        GlyphSegmentedPicker(
                            selection: $viewModel.clickHighlights.effect,
                            options: ClickHighlightStyle.Effect.allCases.map { effect in
                                switch effect {
                                case .off: (effect, "None")
                                case .circle: (effect, "Circle")
                                case .ripple: (effect, "Ripple")
                                }
                            }
                        ) { effect in
                            ClickEffectPicture(effect: effect)
                        }
                    }
                    .inspectorCardRow()
                    // Dimmed rather than hidden, so the column doesn't jump
                    Group {
                        InspectorHairline()
                        InspectorColorRow("Color") {
                            ColorPicker("Color", selection: $viewModel.clickHighlights.color.cgColor)
                        }
                        .inspectorCardRow()
                        InspectorHairline()
                        HStack {
                            Text("Buttons")
                            Spacer()
                            SegmentedChoice(
                                selection: $viewModel.clickHighlights.buttons,
                                options: [(.all, "All"), (.left, "Left Only"), (.right, "Right Only")],
                                trackFill: EditorTheme.panel
                            )
                            .fixedSize()
                        }
                        .inspectorCardRow()
                    }
                    .disabled(!hasEffect)
                    // Text in ink doesn't dim by itself when disabled
                    .opacity(hasEffect ? 1 : 0.4)
                }
            }
            Group {
                SliderBar("Size", value: $viewModel.clickHighlights.size, in: 16...120) {
                    Text("\($0, format: .number.precision(.fractionLength(0))) pt")
                }
                SliderBar("Duration", value: $viewModel.clickHighlights.duration, in: 0.2...1.5) {
                    Text("\($0, format: .number.precision(.fractionLength(1))) s")
                }
            }
            .disabled(!hasEffect)
            SliderBar("Click Sound", value: $viewModel.audio.clickVolume, in: 0...1) {
                $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
            }
        }
        .disabled(viewModel.source?.telemetry == nil)
    }
}
