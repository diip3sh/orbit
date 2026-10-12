//
//  EditorInspectorSections.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The editor's right column: the tab bar, a notice when the telemetry is missing, then the chosen tab's
/// sections, each a card under a small-caps title. Selecting a zoom on the timeline turns to Motion, a
/// mask to Background, where their settings are.
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
                            .font(.theme(.callout))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(EditorTheme.mediumSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .editorSurface(in: .rect(cornerRadius: 8), fill: EditorTheme.control)
                            .padding([.horizontal, .top])
                    }

                    VStack(spacing: EditorTheme.largeSpacing) {
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
                    .padding(EditorTheme.spacing)
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
