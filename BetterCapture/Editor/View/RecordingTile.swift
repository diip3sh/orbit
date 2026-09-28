//
//  RecordingTile.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A recording's picture, name and date, as a button. Under the pointer it lifts and shows what
/// clicking does.
struct RecordingTile: View {
    let recording: Recording
    let thumbnail: CGImage?
    let open: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)

        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                Color.white.opacity(0.05)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            Image(decorative: thumbnail, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity)
                        }
                    }
                    .overlay {
                        if isHovered {
                            Label("Edit", systemImage: "slider.horizontal.3")
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .editorGlass(in: .capsule)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(isHovered ? .white.opacity(0.25) : EditorTheme.hairline)
                    }
                    .shadow(color: .black.opacity(isHovered ? 0.5 : 0.25), radius: isHovered ? 16 : 6, y: isHovered ? 8 : 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(recording.date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .editorMotion(.snappy(duration: 0.22), value: isHovered)
        .editorMotion(.smooth, value: thumbnail != nil)
        .help(recording.url.lastPathComponent)
    }
}
