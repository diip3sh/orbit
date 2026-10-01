//
//  PreviewThumbnailView.swift
//  Reco
//
//  Created by Joshua Sattler on 02.02.26.
//

import SwiftUI

/// Displays a preview thumbnail of the selected capture content with optional live preview
struct PreviewThumbnailView: View {
    let previewImage: NSImage?
    let isLivePreviewActive: Bool
    let onStartLivePreview: () -> Void
    let onStopLivePreview: () -> Void

    @State private var isHovered = false

    var body: some View {
        Group {
            if let image = previewImage {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 8))

                    // Play/Stop button overlay
                    previewControlOverlay
                }
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var previewControlOverlay: some View {
        ZStack {
            // Semi-transparent background when hovered or when showing play button
            if isHovered || !isLivePreviewActive {
                Color.black.opacity(0.3)
                    .clipShape(.rect(cornerRadius: 8))
            }

            // Play/Stop button
            if isHovered || !isLivePreviewActive {
                Button {
                    if isLivePreviewActive {
                        onStopLivePreview()
                    } else {
                        onStartLivePreview()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)

                        Image(systemName: isLivePreviewActive ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            // Live indicator badge
            if isLivePreviewActive {
                VStack {
                    HStack {
                        Spacer()
                        Text("LIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: .capsule)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
    }

    private var placeholderView: some View {
        Button {
            onStartLivePreview()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .overlay {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 48, height: 48)

                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("With Image - Not Live") {
    PreviewThumbnailView(
        previewImage: NSImage(systemSymbolName: "display", accessibilityDescription: nil),
        isLivePreviewActive: false,
        onStartLivePreview: {},
        onStopLivePreview: {}
    )
    .frame(width: 320)
}

#Preview("With Image - Live") {
    PreviewThumbnailView(
        previewImage: NSImage(systemSymbolName: "display", accessibilityDescription: nil),
        isLivePreviewActive: true,
        onStartLivePreview: {},
        onStopLivePreview: {}
    )
    .frame(width: 320)
}

#Preview("Placeholder") {
    PreviewThumbnailView(
        previewImage: nil,
        isLivePreviewActive: false,
        onStartLivePreview: {},
        onStopLivePreview: {}
    )
    .frame(width: 320)
}
