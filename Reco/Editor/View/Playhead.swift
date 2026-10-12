//
//  Playhead.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Where the playhead sits on the timeline. The ruler lives in the toolbar card and the tracks
/// under it, so the playhead is drawn in two pieces that share an x: a knob in the ruler
/// (``PlayheadKnob``) and a line through the tracks (``PlayheadLine``). Both are plain ink, not
/// accent: position is information, not a brand.
enum Playhead {

    static let knobWidth: CGFloat = 11
    static let lineWidth: CGFloat = 1.5
}

/// A line across the timeline's tracks, at the frame shown.
struct PlayheadLine: View {

    var body: some View {
        Rectangle()
            .fill(EditorTheme.ink)
            .frame(width: Playhead.lineWidth)
            .allowsHitTesting(false)
    }
}

/// The playhead's grip in the ruler, pointing down at the tracks.
struct PlayheadKnob: View {

    var body: some View {
        Knob()
            .fill(EditorTheme.ink)
            .frame(width: Playhead.knobWidth, height: 16)
            .allowsHitTesting(false)
    }

    /// Rounded at the top and pointed at the bottom.
    nonisolated private struct Knob: Shape {
        func path(in rect: CGRect) -> Path {
            let point = rect.height * 0.35
            var path = Path()
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - point), cornerSize: CGSize(width: 2.5, height: 2.5))
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY - point - 1))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - point - 1))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}
