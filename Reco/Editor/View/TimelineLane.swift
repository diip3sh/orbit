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

    /// The selected clip, whose trim handles show
    var selection: UUID?

    /// A clip's block, told whether it's being dragged.
    @ViewBuilder let block: (Clip, Bool) -> Block

    /// The clip being dragged and how far it's shown moved, in points.
    @State private var drag: (id: UUID, offset: CGFloat)?

    /// The clip under the pointer, whose trim handles show.
    @State private var hovered: UUID?

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
                    let limits = -start...max(width - end, -start)

                    let showsHandles = clip.id == hovered || clip.id == selection || drag?.id == clip.id

                    block(clip, drag?.id == clip.id)
                        .frame(width: end - start)
                        .offset(x: start + dragged)
                        .onHover { isInside in
                            if isInside {
                                hovered = clip.id
                            } else if hovered == clip.id {
                                hovered = nil
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    // Typed in full: Xcode 26.6 won't convert a Double into a labeled tuple's CGFloat
                                    let offset = CGFloat(GesturePhysics.rubberbanded(value.translation.width, in: limits, dimension: width))
                                    drag = (id: clip.id, offset: offset)
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

                    TrimHandle(edge: .leading, position: start, width: width, isShown: showsHandles) { position in
                        onMoveStart(clip.id, position / width * duration)
                    }
                    TrimHandle(edge: .trailing, position: end, width: width, isShown: showsHandles) { position in
                        onMoveEnd(clip.id, position / width * duration)
                    }
                }
            }
        }
        // minWidth 0: blocks are laid out in points of the last width, which mustn't become the window's minimum
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .background(EditorTheme.softHairline.opacity(0.6), in: .rect(cornerRadius: 6))
    }
}
