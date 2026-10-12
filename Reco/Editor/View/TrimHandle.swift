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

    let onDrop: (CGFloat) -> Void

    @State private var dragPosition: CGFloat?
    @State private var isHovered = false

    /// The grabbable width: the pill is 4 pt, the hand gets more.
    private static let grabWidth: CGFloat = 10

    var body: some View {
        let isActive = isHovered || dragPosition != nil

        Color.clear
            .frame(width: Self.grabWidth)
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .fill(EditorTheme.ink)
                    .frame(width: 4, height: 18)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
            .contentShape(.rect)
            .opacity(isShown || isActive ? 1 : 0)
            .offset(x: (dragPosition ?? position) - Self.grabWidth / 2)
            .pointerStyle(.frameResize(position: edge == .leading ? .leading : .trailing))
            .onHover { isHovered = $0 }
            .editorMotion(EditorTheme.quickMotion, value: isActive)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { dragPosition = GesturePhysics.rubberbanded($0.location.x, in: 0...max(width, 0), dimension: width) }
                    .onEnded { value in
                        let shown = dragPosition ?? value.location.x
                        let settled = min(max(value.location.x, 0), max(width, 0))
                        withMotion(EditorTheme.release(velocity: value.velocity.width, distance: settled - shown)) {
                            dragPosition = nil
                            onDrop(value.location.x)
                        }
                    }
            )
    }
}
