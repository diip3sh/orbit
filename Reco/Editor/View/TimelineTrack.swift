//
//  TimelineTrack.swift
//  Reco
//

import SwiftUI

/// One of the timeline's rows on its rounded, darker lane, with the ruler's grid lines across it and its name in
/// the margin to its left (``EditorTimelineView/trackLabelWidth``), which the timeline leaves free.
struct TimelineTrack<Content: View>: View {
    let title: LocalizedStringKey

    /// Which part of the recording is on screen, for the grid lines.
    let viewport: TimelineViewport

    /// The lane's room above and below the row.
    let inset: CGFloat

    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.vertical, inset)
            .background {
                ZStack {
                    EditorTheme.stage
                    grid
                }
                .clipShape(.rect(cornerRadius: EditorTheme.largeRadius))
            }
            .overlay(alignment: .leading) {
                Text(title)
                    .font(.theme(.callout, weight: .medium))
                    .foregroundStyle(EditorTheme.dim)
                    .lineLimit(1)
                    .frame(width: EditorTimelineView.trackLabelWidth, alignment: .leading)
                    .offset(x: -EditorTimelineView.trackLabelWidth)
                    .allowsHitTesting(false)
            }
    }

    /// A hairline at each of the ruler's labelled times.
    private var grid: some View {
        Canvas { context, size in
            guard viewport.visible > 0 else { return }
            var lines = Path()
            for time in TimelineRuler.majors(in: viewport, width: size.width) {
                let gridX = viewport.x(at: time, width: size.width)
                lines.addRect(CGRect(x: gridX, y: 0, width: 1, height: size.height))
            }
            context.fill(lines, with: .color(EditorTheme.ink.opacity(0.04)))
        }
        .allowsHitTesting(false)
    }
}
