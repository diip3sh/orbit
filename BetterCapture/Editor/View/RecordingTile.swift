//
//  RecordingTile.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A recording's picture, name and date, as a button.
struct RecordingTile: View {
    let recording: Recording
    let thumbnail: CGImage?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading) {
                Color.secondary.opacity(0.15)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            Image(decorative: thumbnail, scale: 1)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipShape(.rect(cornerRadius: 8))
                Text(recording.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(recording.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(recording.url.lastPathComponent)
    }
}
