//
//  MotionScenesLane.swift
//  Reco
//

import SwiftUI

/// The scenes end to end, each as long as it lasts, named by its shot and seam; a click selects one
/// and moves the playhead to its start.
struct MotionScenesLane: View {
    let viewModel: MotionEditorViewModel

    @State private var width: CGFloat = 0

    private static let gap: CGFloat = 2

    var body: some View {
        let scenes = viewModel.document?.scenes ?? []
        let duration = max(viewModel.duration, 1e-3)

        HStack(spacing: Self.gap) {
            ForEach(scenes.indices, id: \.self) { index in
                let scene = scenes[index]
                Button {
                    viewModel.select(scene: index)
                } label: {
                    TimelineBlock(isSelected: index == viewModel.selectedScene, isDragged: false) {
                        HStack(spacing: EditorTheme.tightSpacing) {
                            if scene.seam != .cut {
                                Image(systemName: "arrow.right.to.line")
                                    .help(scene.seam.rawValue)
                            }
                            Text(scene.shot?.kind.rawValue ?? scene.id)
                            Text(scene.duration, format: .number.precision(.fractionLength(1)))
                                .foregroundStyle(EditorTheme.faint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(width: max(width * scene.duration / duration - Self.gap, 1))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28, alignment: .leading)
        .overlay(alignment: .leading) {
            MotionPlayhead(playback: viewModel.playback, duration: duration, width: width)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .padding(EditorTheme.smallSpacing)
        .background(EditorTheme.tray, in: EditorTheme.trayShape)
    }
}

/// A line where the playhead is, redrawn every frame only while playing.
private struct MotionPlayhead: View {
    let playback: PlaybackController
    let duration: Double
    let width: CGFloat

    var body: some View {
        TimelineView(.animation(paused: !playback.isPlaying)) { _ in
            let time = playback.isPlaying ? playback.currentTime : playback.pausedTime
            Rectangle()
                .fill(EditorTheme.accent)
                .frame(width: 2)
                .offset(x: width * min(max(time / duration, 0), 1) - 1)
                .allowsHitTesting(false)
        }
    }
}
