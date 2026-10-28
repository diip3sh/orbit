//
//  TrimHandle.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A handle on one edge of a kept part of the timeline: a small white pill centred on the edge.
/// It follows the pointer while dragged, resisting past the timeline's ends, and reports where it
/// was let go, in the timeline's coordinate space. What the timeline refuses springs back from
/// where the handle was shown.
struct TrimHandle: View {

    /// The timeline's coordinate space, in which ``position`` and drop points are measured.
    static let coordinateSpace = "timeline"

    let edge: HorizontalEdge

    /// Where the kept part's edge is, horizontally. The pill is centred on it.
    let position: CGFloat

    /// The timeline's width: the handle may go from 0 to here before it resists.
    let width: CGFloat

    /// Whether it shows at rest; hidden, it still appears under the pointer and while dragged. Clips
    /// in a lane show theirs only when hovered or selected: on a short clip two handles hide the clip.
    var isShown = true

    var pill = Pill()

    let onDrop: (CGFloat) -> Void

    /// The pill's size, and how far outside the edge it sits.
    struct Pill {
        var height: CGFloat = 18
        var outset: CGFloat = 0
    }

    /// Where the pill is shown while dragged, which is where the pointer is.
    @State private var dragPosition: CGFloat?
    @State private var isHovered = false

    /// The grabbable width: the pill is 4 pt, the hand gets more.
    private static let grabWidth: CGFloat = 10

    var body: some View {
        let isActive = isHovered || dragPosition != nil
        // The pill's distance from the edge it moves
        let shift = edge == .leading ? -pill.outset : pill.outset
        let limits = Double(shift)...Double(max(width, 0) + shift)

        Color.clear
            .frame(width: Self.grabWidth)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .fill(EditorTheme.ink)
                    .frame(width: 4, height: pill.height)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
            .contentShape(.rect)
            .opacity(isShown || isActive ? 1 : 0)
            .offset(x: (dragPosition ?? position + shift) - Self.grabWidth / 2)
            .pointerStyle(.frameResize(position: edge == .leading ? .leading : .trailing))
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isActive)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { dragPosition = GesturePhysics.rubberbanded($0.location.x, in: limits, dimension: width) }
                    .onEnded { value in
                        let shown = dragPosition ?? value.location.x
                        let settled = min(max(value.location.x, limits.lowerBound), limits.upperBound)
                        withMotion(EditorTheme.release(velocity: value.velocity.width, distance: settled - shown)) {
                            dragPosition = nil
                            onDrop(value.location.x - shift)
                        }
                    }
            )
    }
}
