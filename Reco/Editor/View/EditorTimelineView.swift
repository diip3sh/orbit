//
//  EditorTimelineView.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The timeline's tracks: the video row, the clicks & keys row, the audio row, then the zoom and
/// mask lanes, each named on its own lane with a faint grid, with cut parts ghosted, trim handles
/// on the kept parts' edges and the playhead's line. The window on the recording is the view model's viewport: dragging scrubs,
/// clicking selects a part, scrolling pans and ⌘-scrolling zooms.
struct EditorTimelineView: View {
    let viewModel: EditorViewModel

    /// The video's size, whose aspect ratio sizes the filmstrip's tiles.
    let videoSize: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var width: CGFloat = 0
    @State private var showsTelemetry = true
    @State private var hoveredSegment: Range<Double>?

    /// Where the scroll indicator's drag began: its x and the window's start then.
    @State private var indicatorGrab: (x: CGFloat, start: Double)?

    private static let spacing: CGFloat = 6
    private static let trackSpacing: CGFloat = 8
    private static let indicatorHeight: CGFloat = 4

    /// The margin left of the tracks that holds their names: the ruler and the tracks start after it.
    static let trackLabelWidth: CGFloat = 88

    /// The video row's room on its lane, above and below.
    private static let videoInset: CGFloat = 12

    /// How far the pointer may move for a press to still count as a click.
    private static let clickTolerance: CGFloat = 3

    /// The thumbnails to load: which window, cut into how many tiles. Equatable, so a change reloads.
    private struct ThumbnailRequest: Equatable {
        var count: Int
        var start: Double
        var visible: Double
    }

    var body: some View {
        VStack(spacing: Self.spacing) {
            rows
            scrollIndicator
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task(id: thumbnailRequest) {
            // A zoom drag moves the window every tick; let it settle before decoding
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await viewModel.loadThumbnails(count: thumbnailRequest.count, maximumSize: VideoTrack.tileSize(videoSize: videoSize, displayScale: displayScale))
        }
        .task {
            await viewModel.loadWaveform()
        }
        .task(id: viewModel.playback.isPlaying) {
            while viewModel.playback.isPlaying, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                viewModel.keepPlayheadVisible()
            }
        }
    }

    /// The track rows stacked, with the grid, the cut ghosts, the handles and the playhead.
    private var rows: some View {
        let viewport = viewModel.viewport
        return VStack(spacing: Self.trackSpacing) {
            TimelineTrack(title: "Video", viewport: viewport, inset: Self.videoInset) {
                VideoTrack(
                    viewModel: viewModel,
                    videoSize: videoSize,
                    width: width,
                    showsTelemetry: $showsTelemetry,
                    hoveredSegment: $hoveredSegment
                )
            }

            if showsTelemetry, viewModel.markers != nil {
                TimelineTrack(title: "Input", viewport: viewport, inset: 5) {
                    TelemetryLane(viewModel: viewModel, width: width)
                }
            } else if viewModel.source?.telemetryError != nil {
                TimelineTrack(title: "Input", viewport: viewport, inset: 5) {
                    Text("No clicks or keystrokes: recorded without input telemetry")
                        .font(.theme(.caption))
                        .foregroundStyle(EditorTheme.dim)
                        .frame(maxWidth: .infinity)
                        .frame(height: TelemetryLane.height)
                }
            }

            if viewModel.source.map({ !$0.audioTrackIDs.isEmpty }) == true {
                TimelineTrack(title: "Audio", viewport: viewport, inset: 2) {
                    AudioLane(viewModel: viewModel, width: width)
                }
            }

            TimelineTrack(title: "Zoom", viewport: viewport, inset: 3) {
                ZoomLane(viewModel: viewModel, width: width)
            }

            if !viewModel.project.masks.isEmpty {
                TimelineTrack(title: "Masks", viewport: viewport, inset: 3) {
                    MaskLane(viewModel: viewModel, width: width)
                }
                .transition(.opacity)
            }
        }
        .editorMotion(value: viewModel.project.masks.isEmpty)
        .background(
            ScrollWheelRegion { event, point in
                handleScroll(event, at: point)
            }
        )
        .overlay(alignment: .topLeading) {
            cutGhosts
        }
        .overlay(alignment: .topLeading) {
            trimHandles
        }
        .overlay(alignment: .topLeading) {
            playhead
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard width > 0 else { return }
                    viewModel.seek(toSource: viewModel.viewport.time(atX: value.location.x, width: width))
                }
                .onEnded { value in
                    guard width > 0, abs(value.translation.width) < Self.clickTolerance else { return }
                    viewModel.select(at: viewModel.viewport.time(atX: value.location.x, width: width))
                }
        )
        .coordinateSpace(.named(TrimHandle.coordinateSpace))
    }

    /// Cut parts as dashed, hatched ghosts naming what was cut.
    private var cutGhosts: some View {
        Canvas { context, size in
            let viewport = viewModel.viewport
            guard viewport.visible > 0 else { return }
            for cut in viewModel.timeMap.cuts {
                let start = viewport.x(at: cut.lowerBound, width: size.width)
                let end = viewport.x(at: cut.upperBound, width: size.width)
                let area = CGRect(x: start, y: 0, width: end - start, height: size.height)
                    .intersection(CGRect(origin: .zero, size: size))
                guard area.width > 2 else { continue }
                context.fill(Path(area), with: .color(EditorTheme.panel.opacity(0.6)))
                context.fill(Self.hatching(in: area), with: .color(EditorTheme.ink.opacity(0.07)))
                context.stroke(
                    Path(roundedRect: area.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 7),
                    with: .color(EditorTheme.ink.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                guard area.width > 52 else { continue }
                let seconds = (cut.upperBound - cut.lowerBound).formatted(.number.precision(.fractionLength(0...1)))
                let label = context.resolve(
                    Text("Cut · \(seconds) s")
                        .font(.theme(.caption2))
                        .foregroundStyle(EditorTheme.dim)
                )
                context.draw(label, at: CGPoint(x: area.midX, y: area.midY), anchor: .center)
            }
        }
        .allowsHitTesting(false)
    }

    /// A handle on both edges of each kept part, over the video row, shown on hover and selection.
    private var trimHandles: some View {
        ZStack(alignment: .leading) {
            ForEach(viewModel.timeMap.keptRanges.indices, id: \.self) { index in
                let range = viewModel.timeMap.keptRanges[index]
                let shown = showsHandles(for: range)
                TrimHandle(
                    edge: .leading,
                    position: viewModel.viewport.x(at: range.lowerBound, width: width),
                    width: width,
                    isShown: shown
                ) { position in
                    viewModel.moveStart(ofKeptRange: index, to: viewModel.viewport.time(atX: position, width: width))
                }
                TrimHandle(
                    edge: .trailing,
                    position: viewModel.viewport.x(at: range.upperBound, width: width),
                    width: width,
                    isShown: shown
                ) { position in
                    viewModel.moveEnd(ofKeptRange: index, to: viewModel.viewport.time(atX: position, width: width))
                }
            }
        }
        .frame(width: width, height: VideoTrack.height, alignment: .leading)
        // On the video row, inside its lane
        .offset(y: Self.videoInset)
    }

    /// The playhead's line, from the top of the video row to the bottom of the lanes.
    private var playhead: some View {
        TimelineView(.animation(paused: !viewModel.playback.isPlaying)) { _ in
            let position = viewModel.viewport.x(at: viewModel.playheadSourceTime, width: width)
            PlayheadLine()
                .offset(x: position - Playhead.lineWidth / 2)
                .opacity(position >= 0 && position <= width ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    /// The window's place in the whole recording, draggable. Hidden while everything shows.
    private var scrollIndicator: some View {
        let viewport = viewModel.viewport
        let duration = max(viewport.duration, 1)
        return Capsule()
            .fill(EditorTheme.ink.opacity(0.25))
            .frame(width: max(width * viewport.visible / duration, 24), height: Self.indicatorHeight)
            // minWidth 0: the capsule is laid out in points of the last width, which mustn't pin the window
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .offset(x: width * viewport.start / duration)
            .opacity(viewport.showsAll ? 0 : 1)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if indicatorGrab == nil {
                            indicatorGrab = (x: value.startLocation.x, start: viewModel.viewport.start)
                        }
                        guard let grab = indicatorGrab, width > 0 else { return }
                        viewModel.setTimelineStart(grab.start + Double(value.location.x - grab.x) / width * duration)
                    }
                    .onEnded { _ in
                        indicatorGrab = nil
                    }
            )
    }

    /// Horizontal scrolls pan the window, ⌘-scrolls zoom it under the pointer. Used, so they go no
    /// further; a plain vertical scroll pans too, like the trackpad's horizontal one.
    private func handleScroll(_ event: NSEvent, at point: CGPoint) -> Bool {
        let precise = event.hasPreciseScrollingDeltas
        let scale: Double = precise ? 1 : 12
        if event.modifierFlags.contains(.command) {
            let factor = pow(1.002, Double(event.scrollingDeltaY) * (precise ? 1 : 8))
            let anchor = viewModel.viewport.time(atX: point.x, width: width)
            viewModel.zoomTimeline(by: factor, anchor: anchor)
            return true
        }
        let delta = abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY) ? event.scrollingDeltaX : -event.scrollingDeltaY
        guard delta != 0, width > 0 else { return true }
        viewModel.scrollTimeline(by: -Double(delta) * scale / width * viewModel.viewport.visible)
        return true
    }

    /// Whether a kept part's handles show: under the pointer or selected.
    private func showsHandles(for range: Range<Double>) -> Bool {
        if let hoveredSegment, hoveredSegment.overlaps(range) {
            return true
        }
        if case .segment(let selection) = viewModel.selection {
            return selection.overlaps(range)
        }
        return false
    }

    /// What the thumbnails load: one tile per filmstrip tile width across the visible window.
    private var thumbnailRequest: ThumbnailRequest {
        let tileWidth = VideoTrack.tileSize(videoSize: videoSize, displayScale: 1).width
        let count = width > 0 && tileWidth > 0 ? Int((width / tileWidth).rounded(.up)) : 0
        return ThumbnailRequest(count: count, start: viewModel.viewport.start, visible: viewModel.viewport.visible)
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
