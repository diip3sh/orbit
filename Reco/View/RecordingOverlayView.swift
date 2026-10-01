//
//  RecordingOverlayView.swift
//  Reco
//
//  Created by Joshua Sattler on 14.03.26.
//

import SwiftUI

/// The SwiftUI content view hosted inside the recording overlay panel.
/// Shows a live preview and two action buttons: Start Recording and Dismiss. Glass in the editor's
/// dark look; it arrives from and returns to the status item above it.
struct RecordingOverlayView: View {
    let viewModel: RecorderViewModel
    let presence: PanelPresence
    let onDismiss: () -> Void

    @State private var currentPreview: NSImage?

    var body: some View {
        VStack(spacing: 0) {
            previewArea
            buttonRow
        }
        .padding(10)
        .padding(.top, 4)
        .editorGlass(in: .rect(cornerRadius: 16))
        .foregroundStyle(EditorTheme.ink)
        .panelPresentation(isPresented: presence.isShown, anchor: .top)
        .onChange(of: viewModel.previewService.previewImage) { _, newImage in
            currentPreview = newImage
        }
        .onAppear {
            currentPreview = viewModel.previewService.previewImage
        }
    }

    // MARK: - Preview Area

    private var previewArea: some View {
        ZStack {
            if let image = currentPreview {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.15))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }

            // Only shown when preview is streaming
            if viewModel.previewService.isCapturing {
                VStack {
                    HStack {
                        Spacer()
                        LiveIndicator()
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    // MARK: - Buttons

    private var buttonRow: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    await viewModel.startRecordingWithCountdown()
                }
            } label: {
                Label("Start Recording", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.editorPrimary)

            Button {
                onDismiss()
            } label: {
                Text("Dismiss")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.editorGhost)
        }
        .padding(.top, 10)
    }
}
