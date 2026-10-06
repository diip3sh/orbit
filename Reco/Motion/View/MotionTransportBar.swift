//
//  MotionTransportBar.swift
//  Reco
//

import SwiftUI

/// Play/pause and frame stepping in the middle, the playhead's time on the right, on glass.
struct MotionTransportBar: View {
    let viewModel: MotionEditorViewModel

    var body: some View {
        EditorGlassGroup {
            HStack {
                Spacer()
                PlaybackTime(playback: viewModel.playback, duration: viewModel.duration)
                    .padding(.horizontal, EditorTheme.spacing)
                    .frame(height: 38)
                    .editorGlass(in: .capsule)
            }
            .overlay {
                PlaybackControls(playback: viewModel.playback)
                    .padding(EditorTheme.tightSpacing)
                    .editorGlass(in: .capsule)
            }
        }
        .buttonStyle(.editorIcon)
    }
}
