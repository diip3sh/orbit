//
//  RecordingsView.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The output folder's recordings as a grid of pictures. Clicking one opens it in the editor.
/// ``EditorWindowManager`` reloads the list whenever the window comes forward.
struct RecordingsView: View {
    let viewModel: RecordingsViewModel

    var body: some View {
        Group {
            if let error = viewModel.error {
                ContentUnavailableView(
                    "Can't Read the Output Folder", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription)
                )
            } else if let recordings = viewModel.recordings {
                if recordings.isEmpty {
                    ContentUnavailableView(
                        "No Recordings", systemImage: "film.stack", description: Text("Recordings saved to the output folder appear here.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: EditorTheme.largeSpacing)], spacing: EditorTheme.largeSpacing) {
                            ForEach(recordings) { recording in
                                RecordingTile(recording: recording, thumbnail: viewModel.thumbnails[recording.url]) {
                                    viewModel.open(recording)
                                }
                                .task {
                                    await viewModel.loadThumbnail(for: recording)
                                }
                            }
                        }
                        .padding(EditorTheme.largeSpacing)
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .editorWindowBackground()
    }
}
