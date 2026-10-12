//
//  AudioLane.swift
//  Reco
//
//  Created by Diip3sh on 10.10.26.
//

import SwiftUI

/// The timeline's audio row: one accent-tinted clip per kept part with a header naming the tracks,
/// over the mix's waveform. Shown when the recording has audio; cut parts are left empty for the
/// cut ghosts behind.
struct AudioLane: View {
    let viewModel: EditorViewModel

    /// The timeline's width, in points.
    let width: CGFloat

    static let height: CGFloat = 40

    /// The header's height; the waveform fills what's under it.
    private static let headerHeight: CGFloat = 16

    var body: some View {
        let viewport = viewModel.viewport

        ZStack(alignment: .topLeading) {
            ForEach(viewModel.segments, id: \.lowerBound) { segment in
                let start = viewport.x(at: segment.lowerBound, width: width)
                let end = viewport.x(at: segment.upperBound, width: width)
                AudioPart(
                    name: trackName,
                    isSelected: viewModel.selection == .segment(segment),
                    // The header stays on screen while its part is, even with the start scrolled off
                    stickyOffset: min(max(-start, 0), max(end - start - 72, 0))
                )
                .frame(width: max(end - start, 1), height: Self.height)
                .offset(x: start)
            }

            waveform
                .frame(height: Self.height - Self.headerHeight)
                .mask(partsMask)
                .offset(y: Self.headerHeight)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
    }

    /// The tracks' names, joined when there's more than one.
    private var trackName: String {
        viewModel.source?.audioTrackNames.joined(separator: " & ") ?? "Audio"
    }

    /// One bar per point of width, as tall as the mix's peak at that time.
    private var waveform: some View {
        Canvas { context, size in
            let peaks = viewModel.waveform
            guard !peaks.isEmpty, size.width > 0 else { return }
            var bars = Path()
            let middle = size.height / 2
            var column: CGFloat = 0
            while column < size.width {
                let time = viewModel.viewport.time(atX: column + 0.5, width: size.width)
                let bucket = min(max(Int(time * Double(WaveformLoader.bucketsPerSecond)), 0), peaks.count - 1)
                let height = max(CGFloat(peaks[bucket]) * (size.height - 2), 1)
                bars.addRoundedRect(
                    in: CGRect(x: column, y: middle - height / 2, width: 1, height: height),
                    cornerSize: CGSize(width: 0.5, height: 0.5)
                )
                column += 1
            }
            // accentFill, not accent: the audio green is the app's, whatever the system accent
            context.fill(bars, with: .color(EditorTheme.accentFill.opacity(0.85)))
        }
        .allowsHitTesting(false)
    }

    /// The waveform shows only inside the kept parts.
    private var partsMask: some View {
        Canvas { context, size in
            for segment in viewModel.segments {
                let start = viewModel.viewport.x(at: segment.lowerBound, width: size.width)
                let end = viewModel.viewport.x(at: segment.upperBound, width: size.width)
                context.fill(Path(CGRect(x: start, y: 0, width: end - start, height: size.height)), with: .color(.white))
            }
        }
    }
}

/// One kept part of the audio row.
private struct AudioPart: View {
    let name: String
    let isSelected: Bool

    /// How far the header slides right to stay on screen while the part's start is scrolled off.
    let stickyOffset: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7)

        shape
            .fill(EditorTheme.accentFill.opacity(0.16))
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
                    Image(systemName: "speaker.wave.2.fill")
                    Text(name)
                    Spacer(minLength: 0)
                }
                .font(.theme(.caption2, weight: .semibold))
                .foregroundStyle(EditorTheme.accentFill.opacity(0.9))
                .padding(.horizontal, 6)
                .frame(height: 16)
                .offset(x: stickyOffset)
            }
            .clipShape(shape)
    }
}
