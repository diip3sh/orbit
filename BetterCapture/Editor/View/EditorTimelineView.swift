//
//  EditorTimelineView.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The timeline: a filmstrip, click and keystroke lanes, and the playhead. Dragging anywhere scrubs.
struct EditorTimelineView: View {
    let viewModel: EditorViewModel

    /// The video's size, whose aspect ratio sizes the filmstrip's tiles.
    let videoSize: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0

    private static let filmstripHeight: CGFloat = 48
    private static let lanesHeight: CGFloat = 20

    var body: some View {
        let duration = viewModel.timeMap.outputDuration
        let tileWidth = Self.filmstripHeight * videoSize.width / max(videoSize.height, 1)
        let tileCount = Int((width / tileWidth).rounded(.up))

        VStack(alignment: .leading) {
            HStack(spacing: 0) {
                ForEach(viewModel.thumbnails.indices, id: \.self) { index in
                    Group {
                        if let image = viewModel.thumbnails[index] {
                            Image(decorative: image, scale: displayScale)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Color.black
                        }
                    }
                    .frame(width: width / CGFloat(viewModel.thumbnails.count), height: Self.filmstripHeight)
                    .clipped()
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.filmstripHeight, maxHeight: Self.filmstripHeight, alignment: .leading)
            .background(.black)
            .clipShape(.rect(cornerRadius: 4))

            if let markers = viewModel.markers {
                Canvas { context, size in
                    guard duration > 0 else { return }
                    let laneHeight = size.height / 2
                    let clickLane = CGRect(x: 0, y: 0, width: size.width, height: laneHeight - 1)
                    let keyLane = CGRect(x: 0, y: laneHeight + 1, width: size.width, height: laneHeight - 1)
                    context.fill(Self.ticks(at: markers.clicks, duration: duration, in: clickLane), with: .color(.orange))
                    context.fill(Self.ticks(at: markers.keys, duration: duration, in: keyLane), with: .color(.teal))
                }
                .frame(height: Self.lanesHeight)
                .help("Clicks (orange) and keystrokes (teal)")
            } else if let reason = viewModel.source?.telemetryError {
                Text(reason.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: Self.lanesHeight)
            }
        }
        .overlay(alignment: .leading) {
            TimelineView(.animation(paused: !viewModel.playback.isPlaying)) { _ in
                Rectangle()
                    .fill(.red)
                    .frame(width: 2)
                    .offset(x: duration > 0 ? viewModel.playback.currentTime / duration * width - 1 : 0)
            }
            .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0).onChanged { value in
                guard width > 0 else { return }
                viewModel.playback.seek(to: value.location.x / width * duration)
            }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task(id: tileCount) {
            let tileSize = CGSize(width: tileWidth * displayScale, height: Self.filmstripHeight * displayScale)
            await viewModel.loadThumbnails(count: tileCount, maximumSize: tileSize)
        }
    }

    /// One-point-wide ticks at `times`, spanning `lane` vertically, as a single path.
    private static func ticks(at times: [Double], duration: Double, in lane: CGRect) -> Path {
        var path = Path()
        for time in times {
            path.addRect(CGRect(x: lane.minX + time / duration * lane.width - 0.5, y: lane.minY, width: 1, height: lane.height))
        }
        return path
    }
}
