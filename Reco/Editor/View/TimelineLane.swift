//
//  TimelineLane.swift
//  Reco
//

import SwiftUI

/// A timeline lane of clips: clicking one selects it, dragging moves it, and its handles resize it.
/// Moves and resizes are reported in seconds when the pointer lets go. A drag past the lane's ends
/// resists, and on release what the lane refuses springs back from where it was shown.
struct TimelineLane<Clip: TimelineClip, Block: View>: View {
    let clips: [Clip]

    /// The timeline's length in seconds, laid out across ``width``.
    let duration: Double
    let width: CGFloat

    let onSelect: (UUID) -> Void

    /// Moves a clip by an offset in seconds.
    let onMove: (UUID, Double) -> Void

    /// Moves a clip's start or end to a time.
    let onMoveStart: (UUID, Double) -> Void
    let onMoveEnd: (UUID, Double) -> Void

    /// A clip's block, told whether it's being dragged.
    @ViewBuilder let block: (Clip, Bool) -> Block

    /// The clip being dragged and how far it's shown moved, in points.
    @State private var drag: (id: UUID, offset: CGFloat)?

    static var height: CGFloat { 24 }

    /// How far the pointer may move for a press to still count as a click.
    private static var clickTolerance: CGFloat { 3 }

    var body: some View {
        ZStack(alignment: .leading) {
            if duration > 0 {
                ForEach(clips) { clip in
                    let start = clip.range.lowerBound / duration * width
                    let end = clip.range.upperBound / duration * width
                    let dragged = drag.flatMap { $0.id == clip.id ? $0.offset : nil } ?? 0

                    // Where the block may go: its edges stay in the lane
                    let limits: ClosedRange<Double> = -start...max(width - end, -start)

                    block(clip, drag?.id == clip.id)
                        .frame(width: end - start)
                        .offset(x: start + dragged)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    drag = (clip.id, CGFloat(GesturePhysics.rubberbanded(value.translation.width, in: limits, dimension: width)))
                                }
                                .onEnded { value in
                                    let shown = drag?.offset ?? value.translation.width
                                    let settled = min(max(value.translation.width, limits.lowerBound), limits.upperBound)
                                    withMotion(EditorTheme.release(velocity: value.velocity.width, distance: settled - shown)) {
                                        drag = nil
                                        if abs(value.translation.width) < Self.clickTolerance {
                                            onSelect(clip.id)
                                        } else {
                                            onMove(clip.id, value.translation.width / width * duration)
                                        }
                                    }
                                }
                        )

                    TrimHandle(edge: .leading, position: start, width: width) { position in
                        onMoveStart(clip.id, position / width * duration)
                    }
                    TrimHandle(edge: .trailing, position: end, width: width) { position in
                        onMoveEnd(clip.id, position / width * duration)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .background(EditorTheme.softHairline.opacity(0.6), in: .rect(cornerRadius: 6))
    }
}
