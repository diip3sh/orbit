//
//  CameraFootageCard.swift
//  Reco
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Adding, replacing, removing and restoring the camera footage.
struct CameraFootageCard: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let hasFootage = viewModel.source?.camera != nil
        let isShown = viewModel.cameraStyle.isEnabled

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Camera")
            InspectorCard {
                VStack(alignment: .leading, spacing: 0) {
                    if !hasFootage {
                        Label("No camera footage yet. Add a video, or turn the camera on before recording.", systemImage: "web.camera")
                            .foregroundStyle(EditorTheme.dim)
                            .inspectorCardRow()
                        InspectorHairline()
                    }
                    HStack(spacing: EditorTheme.spacing) {
                        Button(hasFootage ? "Replace Footage" : "Add Footage", systemImage: "plus", action: chooseFootage)
                        if hasFootage && isShown {
                            Button("Remove", systemImage: "minus", action: viewModel.removeCameraFootage)
                        } else if hasFootage {
                            Button("Restore", systemImage: "arrow.uturn.backward") {
                                viewModel.cameraStyle.isEnabled = true
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .inspectorCardRow()
                }
            }
            if viewModel.source?.camera?.hasRecordedOffset == false {
                InspectorNote("This footage starts with the recording. If it's out of sync, adjust Time Offset.")
            }
        }
    }

    private func chooseFootage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Camera Footage"
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.addCameraFootage(from: url) }
        }
    }
}
