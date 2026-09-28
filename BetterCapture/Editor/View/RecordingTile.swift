//
//  RecordingTile.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A recording's picture, name and date, as a button that opens it. Under the pointer the picture
/// lightens and its edge lights up.
struct RecordingTile: View {
    let recording: Recording
    let thumbnail: CGImage?
    let open: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10)

        Button(action: open) {
            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
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
                    .overlay(.white.opacity(isHovered ? 0.06 : 0))
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(isHovered ? .white.opacity(0.4) : EditorTheme.hairline, lineWidth: isHovered ? 1.5 : 1)
                    }

                VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
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
