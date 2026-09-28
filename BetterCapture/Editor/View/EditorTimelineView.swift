//
//  EditorTimelineView.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The timeline: the whole recording as a filmstrip with click and keystroke lanes, cut parts
/// dimmed, and the playhead. Dragging scrubs, clicking selects a segment, and the handles on each
/// kept part's edges trim it.
struct EditorTimelineView: View {
    let viewModel: EditorViewModel

    /// The video's size, whose aspect ratio sizes the filmstrip's tiles.
    let videoSize: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0

    private static let filmstripHeight: CGFloat = 48
    private static let lanesHeight: CGFloat = 20

    /// How far the pointer may move for a press to still count as a click.
    private static let clickTolerance: CGFloat = 3

    var body: some View {
        let timeMap = viewModel.timeMap
        let duration = timeMap.sourceDuration
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
        .overlay {
            // Cuts dimmed, splits across the filmstrip (handles cover the kept parts' starts), the selection outlined
            Canvas { context, size in
                guard duration > 0 else { return }
                let span = { (range: Range<Double>, height: CGFloat) in
                    CGRect(x: range.lowerBound / duration * size.width, y: 0, width: (range.upperBound - range.lowerBound) / duration * size.width, height: height)
                }
                for cut in timeMap.cuts {
                    context.fill(Path(span(cut, size.height)), with: .color(.black.opacity(0.6)))
                }
                for segment in viewModel.segments {
                    context.fill(Path(span(segment, Self.filmstripHeight).divided(atDistance: 1, from: .minXEdge).slice), with: .color(.white))
                }
                if let selection = viewModel.selection {
                    context.stroke(Path(roundedRect: span(selection, size.height).insetBy(dx: 1, dy: 1), cornerRadius: 4), with: .color(.accentColor), lineWidth: 2)
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if duration > 0 {
                ZStack(alignment: .leading) {
                    ForEach(timeMap.keptRanges.indices, id: \.self) { index in
                        let range = timeMap.keptRanges[index]
                        TrimHandle(edge: .leading, position: range.lowerBound / duration * width) { position in
                            viewModel.moveStart(ofKeptRange: index, to: position / width * duration)
                        }
                        TrimHandle(edge: .trailing, position: range.upperBound / duration * width) { position in
                            viewModel.moveEnd(ofKeptRange: index, to: position / width * duration)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Self.filmstripHeight, maxHeight: Self.filmstripHeight, alignment: .leading)
            }
        }
        .overlay(alignment: .leading) {
            TimelineView(.animation(paused: !viewModel.playback.isPlaying)) { _ in
                Rectangle()
                    .fill(.red)
                    .frame(width: 2)
                    .offset(x: duration > 0 ? viewModel.playheadSourceTime / duration * width - 1 : 0)
            }
            .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard width > 0 else { return }
                    viewModel.seek(toSource: value.location.x / width * duration)
                }
                .onEnded { value in
                    guard width > 0, abs(value.translation.width) < Self.clickTolerance else { return }
                    viewModel.select(at: value.location.x / width * duration)
                }
        )
        .coordinateSpace(.named(TrimHandle.coordinateSpace))
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
