//
//  RecordingTile.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A recording's picture, name and date, as a button that opens it. Under the pointer the
/// picture's edge turns purple.
struct RecordingTile: View {
    let recording: Recording
    let thumbnail: CGImage?
    let open: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6)

        Button(action: open) {
            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                EditorTheme.softHairline
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            Image(decorative: thumbnail, scale: 1)
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity)
                        }
                    }
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(isHovered ? EditorTheme.faint : EditorTheme.softHairline)
                    }

                VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                    Text(recording.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(recording.date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption)
                        .monospaced()
                        .foregroundStyle(EditorTheme.dim)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        .editorMotion(.smooth, value: thumbnail != nil)
        .help(recording.url.lastPathComponent)
    }
}
