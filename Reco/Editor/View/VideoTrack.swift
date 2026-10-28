//
//  VideoTrack.swift
//  Reco
//
//  Created by Diip3sh on 10.10.26.
//

import SwiftUI

/// The timeline's video row: one violet clip per kept part, each with a header (a chevron for the
/// clicks & keys row, a film icon and the recording's kind, plus the part's speed when it isn't 1×)
/// over a filmstrip of the visible window, cut parts left empty for the cut ghosts behind.
struct VideoTrack: View {
    let viewModel: EditorViewModel

    /// The video's size, whose aspect ratio sizes the filmstrip's tiles.
    let videoSize: CGSize

    /// The timeline's width, in points.
    let width: CGFloat

    /// Whether the clicks & keys row shows, toggled by the header's chevron.
    @Binding var showsTelemetry: Bool

    /// The part under the pointer, whose trim handles show.
    @Binding var hoveredSegment: Range<Double>?

    @Environment(\.displayScale) private var displayScale

    static let height: CGFloat = 46
    static let headerHeight: CGFloat = 16

    /// The clips' violet, at full strength in the headers and faded in the bodies.
    static let tint = Color(red: 0x7d / 255, green: 0x6b / 255, blue: 0xf2 / 255)

    var body: some View {
        let viewport = viewModel.viewport
        let segments = viewModel.segments

        ZStack(alignment: .topLeading) {
            ForEach(segments, id: \.lowerBound) { segment in
                let start = viewport.x(at: segment.lowerBound, width: width)
                let end = viewport.x(at: segment.upperBound, width: width)
                VideoPart(
                    rate: viewModel.timeMap.rate(atSource: (segment.lowerBound + segment.upperBound) / 2),
                    isSelected: viewModel.selection == .segment(segment),
                    showsTelemetry: $showsTelemetry,
                    canShowTelemetry: viewModel.markers != nil,
                    // The header stays on screen while its part is, even with the start scrolled off
                    stickyOffset: min(max(-start, 0), max(end - start - 72, 0))
                )
                .frame(width: max(end - start, 1), height: Self.height)
                .offset(x: start)
                .onHover { inside in
                    hoveredSegment = inside ? segment : (hoveredSegment == segment ? nil : hoveredSegment)
                }
            }

            filmstrip
                .frame(height: Self.height - Self.headerHeight)
                .mask(partsMask)
                .offset(y: Self.headerHeight)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .editorMotion(.smooth, value: viewModel.thumbnails.count { $0 != nil })
    }

    /// The visible window as frames, one tile per `tileWidth` points.
    private var filmstrip: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.thumbnails.indices, id: \.self) { index in
                Group {
                    if let image = viewModel.thumbnails[index] {
                        Image(decorative: image, scale: displayScale)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: width / CGFloat(max(viewModel.thumbnails.count, 1)))
                .clipped()
            }
        }
    }

    /// The filmstrip shows only inside the kept parts.
    private var partsMask: some View {
        Canvas { context, size in
            for segment in viewModel.segments {
                let start = viewModel.viewport.x(at: segment.lowerBound, width: size.width)
                let end = viewModel.viewport.x(at: segment.upperBound, width: size.width)
                context.fill(Path(CGRect(x: start, y: 0, width: end - start, height: size.height)), with: .color(.white))
            }
        }
    }

    /// The tile size a thumbnail is decoded for, in pixels.
    static func tileSize(videoSize: CGSize, displayScale: CGFloat) -> CGSize {
        let width = (height - headerHeight) * videoSize.width / max(videoSize.height, 1)
        return CGSize(width: width * displayScale, height: (height - headerHeight) * displayScale)
    }
}

/// One kept part of the video track.
private struct VideoPart: View {
    let rate: Double
    let isSelected: Bool
    @Binding var showsTelemetry: Bool
    let canShowTelemetry: Bool

    /// How far the header slides right to stay on screen while the part's start is scrolled off.
    let stickyOffset: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7)

        shape
            .fill(VideoTrack.tint.opacity(0.18))
            .overlay {
                shape.strokeBorder(EditorTheme.hairline, lineWidth: 1)
            }
            .overlay {
                if isSelected {
                    shape.strokeBorder(EditorTheme.ink.opacity(0.45), lineWidth: 1.5)
                }
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: 4) {
                    if canShowTelemetry {
                        Button {
                            withMotion(EditorTheme.quickMotion) {
                                showsTelemetry.toggle()
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .rotationEffect(showsTelemetry ? .zero : .degrees(-90))
                        }
                        .buttonStyle(.plain)
                        .help(showsTelemetry ? "Hide clicks and keystrokes" : "Show clicks and keystrokes")
                    }
                    Image(systemName: "film")
                    Text("Screen")
                    Spacer(minLength: 0)
                    if rate != 1 {
                        Text(SpeedRange.label(for: rate))
                            .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(EditorTheme.ink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(EditorTheme.stage.opacity(0.6), in: .rect(cornerRadius: 3))
                    }
                }
                .font(.theme(.caption2, weight: .semibold))
                .foregroundStyle(VideoTrack.tint.opacity(0.9))
                .padding(.horizontal, 6)
                .frame(height: VideoTrack.headerHeight)
                .offset(x: stickyOffset)
            }
            .clipShape(shape)
    }
}
