//
//  EditorTimelineView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The timeline: a time ruler over the whole recording as a filmstrip, with click, keystroke and
/// zoom lanes, cut parts dimmed, and the playhead. Dragging scrubs, clicking selects a segment, and
/// the handles on each kept part's edges trim it.
struct EditorTimelineView: View {
    let viewModel: EditorViewModel

    /// The video's size, whose aspect ratio sizes the filmstrip's tiles.
    let videoSize: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0

    private static let rulerHeight: CGFloat = 16
    private static let filmstripHeight: CGFloat = 52
    private static let lanesHeight: CGFloat = 22
    private static let spacing = EditorTheme.smallSpacing

    /// Where the filmstrip starts, under the ruler.
    private static let filmstripTop = rulerHeight + spacing

    /// How far the pointer may move for a press to still count as a click.
    private static let clickTolerance: CGFloat = 3

    var body: some View {
        let timeMap = viewModel.timeMap
        let duration = timeMap.sourceDuration
        let tileWidth = Self.filmstripHeight * videoSize.width / max(videoSize.height, 1)
        let tileCount = Int((width / tileWidth).rounded(.up))

        VStack(alignment: .leading, spacing: Self.spacing) {
            TimelineRuler(duration: duration)
                .frame(height: Self.rulerHeight)

            HStack(spacing: 0) {
                ForEach(viewModel.thumbnails.indices, id: \.self) { index in
                    Group {
                        if let image = viewModel.thumbnails[index] {
                            Image(decorative: image, scale: displayScale)
                                .resizable()
                                .scaledToFill()
                                .transition(.opacity)
                        } else {
                            EditorTheme.softHairline
                        }
                    }
                    .frame(width: width / CGFloat(viewModel.thumbnails.count), height: Self.filmstripHeight)
                    .clipped()
                }
            }
            // No least width: the tiles are sized from the width measured, so they'd keep a narrowing window wide
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: Self.filmstripHeight, maxHeight: Self.filmstripHeight, alignment: .leading)
            .background(EditorTheme.softHairline)
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(EditorTheme.softHairline)
            }

            if let markers = viewModel.markers {
                Canvas { context, size in
                    guard duration > 0 else { return }
                    let laneHeight = (size.height - 2) / 2
                    let clickLane = CGRect(x: 0, y: 0, width: size.width, height: laneHeight)
                    let keyLane = CGRect(x: 0, y: laneHeight + 2, width: size.width, height: laneHeight)
                    for lane in [clickLane, keyLane] {
                        context.fill(Path(roundedRect: lane, cornerRadius: 2), with: .color(EditorTheme.softHairline))
                    }
                    context.fill(Self.ticks(at: markers.clicks, duration: duration, in: clickLane), with: .color(EditorTheme.ink.opacity(0.8)))
                    context.fill(Self.ticks(at: markers.keys, duration: duration, in: keyLane), with: .color(EditorTheme.dim))
                }
                .frame(height: Self.lanesHeight)
                .help("Clicks (top) and keystrokes (bottom)")
            } else if viewModel.source?.telemetryError != nil {
                Text("No clicks or keystrokes: recorded without input telemetry")
                    .font(.caption)
                    .foregroundStyle(EditorTheme.dim)
                    .frame(height: Self.lanesHeight)
            }

            ZoomLane(viewModel: viewModel, width: width)
        }
        .editorMotion(.smooth, value: viewModel.thumbnails.count { $0 != nil })
        .overlay {
            // Cuts dimmed and hatched, and splits across the filmstrip (handles cover the kept parts' starts)
            Canvas { context, size in
                guard duration > 0 else { return }
                let span = { (range: Range<Double>, top: CGFloat, height: CGFloat) in
                    CGRect(x: range.lowerBound / duration * size.width, y: top, width: (range.upperBound - range.lowerBound) / duration * size.width, height: height)
                }
                for cut in timeMap.cuts {
                    let area = span(cut, Self.filmstripTop, size.height - Self.filmstripTop)
                    context.fill(Path(area), with: .color(.black.opacity(0.6)))
                    context.fill(Self.hatching(in: area), with: .color(.white.opacity(0.07)))
                }
                for segment in viewModel.segments {
                    let line = span(segment, Self.filmstripTop, Self.filmstripHeight).divided(atDistance: 1, from: .minXEdge).slice
                    context.fill(Path(line), with: .color(EditorTheme.ink.opacity(0.8)))
                }
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            if case .segment(let selection) = viewModel.selection, duration > 0 {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(EditorTheme.accent, lineWidth: 2)
                    .background(EditorTheme.accent.opacity(0.08), in: .rect(cornerRadius: 6))
                    .frame(width: (selection.upperBound - selection.lowerBound) / duration * width)
                    .frame(maxHeight: .infinity)
                    .offset(x: selection.lowerBound / duration * width)
                    .padding(.top, Self.filmstripTop)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .editorMotion(value: viewModel.selection)
        .overlay(alignment: .topLeading) {
            if duration > 0 {
                ZStack(alignment: .leading) {
                    ForEach(timeMap.keptRanges.indices, id: \.self) { index in
                        let range = timeMap.keptRanges[index]
                        TrimHandle(edge: .leading, position: range.lowerBound / duration * width, width: width) { position in
                            viewModel.moveStart(ofKeptRange: index, to: position / width * duration)
                        }
                        TrimHandle(edge: .trailing, position: range.upperBound / duration * width, width: width) { position in
                            viewModel.moveEnd(ofKeptRange: index, to: position / width * duration)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Self.filmstripHeight, maxHeight: Self.filmstripHeight, alignment: .leading)
                .padding(.top, Self.filmstripTop)
            }
        }
        .overlay(alignment: .topLeading) {
            TimelineView(.animation(paused: !viewModel.playback.isPlaying)) { _ in
                Playhead(knobHeight: Self.rulerHeight)
                    .offset(x: duration > 0 ? viewModel.playheadSourceTime / duration * width - Playhead.knobWidth / 2 : 0)
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

    /// Rounded ticks at `times`, spanning `lane` vertically, as a single path.
    private static func ticks(at times: [Double], duration: Double, in lane: CGRect) -> Path {
        var path = Path()
        for time in times {
            let center = lane.minX + time / duration * lane.width
            path.addRoundedRect(in: CGRect(x: center - 1, y: lane.minY + 2, width: 2, height: lane.height - 4), cornerSize: CGSize(width: 1, height: 1))
        }
        return path
    }

    /// Diagonal stripes filling `area`, the usual picture of something left out.
    private static func hatching(in area: CGRect) -> Path {
        var path = Path()
        let gap: CGFloat = 6
        var stripeStart = area.minX - area.height
        while stripeStart < area.maxX {
            path.move(to: CGPoint(x: stripeStart, y: area.maxY))
            path.addLine(to: CGPoint(x: stripeStart + area.height, y: area.minY))
            path.addLine(to: CGPoint(x: stripeStart + area.height + 1.5, y: area.minY))
            path.addLine(to: CGPoint(x: stripeStart + 1.5, y: area.maxY))
            path.closeSubpath()
            stripeStart += gap
        }
        return path.intersection(Path(area))
    }
}
