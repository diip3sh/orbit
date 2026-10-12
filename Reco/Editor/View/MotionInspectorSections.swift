//
//  MotionInspectorSections.swift
//  Reco
//

import SwiftUI

/// How the camera and the drawn cursor move.
struct MotionInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry
        let cursorIsRecorded = telemetry?.capture.cursorInVideo != false

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Motion")
            InspectorCard {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                        Text("Zoom")
                        SegmentedChoice(
                            selection: $viewModel.zoomMotion,
                            options: [(.mellow, "Mellow"), (.smooth, "Smooth"), (.fast, "Fast")],
                            trackFill: EditorTheme.panel
                        )
                    }
                    .inspectorCardRow()
                    InspectorHairline()
                    VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                        Text("Cursor")
                        SegmentedChoice(
                            selection: $viewModel.cursor.smoothing,
                            options: [(.mellow, "Mellow"), (.smooth, "Smooth"), (.fast, "Fast"), (.off, "None")],
                            trackFill: EditorTheme.panel
                        )
                        .disabled(cursorIsRecorded)
                    }
                    // Text in ink doesn't dim by itself when disabled
                    .opacity(cursorIsRecorded ? 0.4 : 1)
                    .inspectorCardRow()
                }
            }
            SliderBar("Motion Blur", value: $viewModel.motionBlur, in: 0...1) {
                $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
            }
            if viewModel.motionBlur > 0, viewModel.project.zooms.isEmpty {
                InspectorNote("Blurs the camera's moves; frames without them stay sharp.")
            }
            if telemetry?.capture.cursorInVideo == true {
                InspectorNote("The cursor is part of this recording's video, so it moves as it was recorded.")
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

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Zoom")
            if let zoom = Binding(unwrapping: $viewModel.selectedZoom) {
                SliderBar("Scale", value: zoom.scale, in: 1.25...4) {
                    Text("\($0, format: .number.precision(.fractionLength(0...2)))×")
                }
                InspectorCard {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Focus")
                            Spacer()
                            SegmentedChoice(
                                selection: zoom.followsCursor,
                                options: [(true, "Follow Cursor"), (false, "Fixed")],
                                trackFill: EditorTheme.panel
                            )
                            .fixedSize()
                            .disabled(telemetry == nil)
                        }
                        .inspectorCardRow()
                        if let center = Binding(unwrapping: zoom.fixedCenter), let videoSize = viewModel.videoSize {
                            InspectorHairline()
                            ZoomFocusPad(
                                image: viewModel.croppedThumbnail(at: zoom.wrappedValue.range.lowerBound),
                                videoSize: videoSize,
                                scale: zoom.wrappedValue.scale,
                                baseView: viewModel.baseView,
                                center: center
                            )
                            .padding(6)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }
                }
                .transition(.opacity)
            } else {
                InspectorCard {
                    Label("Select a zoom on the timeline to change it.", systemImage: "cursorarrow.click")
                        .foregroundStyle(EditorTheme.dim)
                        .inspectorCardRow()
                }
                .transition(.opacity)
            }
            Button {
                viewModel.regenerateZooms()
            } label: {
                Label("Regenerate Automatic Zooms", systemImage: "wand.and.sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.editorSecondary)
            .disabled(telemetry == nil)
            if telemetry?.clicks.isEmpty == true {
                if isWebTake {
                    InspectorNote("""
                        This take has no clicks, so automatic zooms come only from where the cursor rested. \
                        Press Z to add one at the playhead.
                        """)
                } else {
                    InspectorNote("""
                        No clicks were recorded (they need Input Monitoring), so automatic zooms come only from \
                        where the cursor rested or circled. Press Z to add one at the playhead.
                        """)
                }
            }
            if viewModel.zoomsLookSoft {
                if isWebTake {
                    InspectorNote("Zoomed parts look soft: this take was rendered at 1×. Render it at 2× in the Web Recording window.")
                } else {
                    InspectorNote("""
                        Zoomed parts look soft: this recording has fewer than 2 pixels per screen point. \
                        On a Retina display, turn on Native Resolution in Settings → Video → Advanced.
                        """)
                }
            }
        }
        .editorMotion(value: viewModel.selectedZoom)
    }
}
