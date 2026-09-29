//
//  TrimHandle.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// A handle on one edge of a kept part of the timeline. It follows the pointer while dragged and
/// reports where it was let go, in the timeline's coordinate space.
struct TrimHandle: View {

    /// The timeline's coordinate space, in which ``position`` and drop points are measured.
    static let coordinateSpace = "timeline"

    let edge: HorizontalEdge

    /// Where the kept part's edge is, horizontally. The handle sits inside the part.
    let position: CGFloat

    let onDrop: (CGFloat) -> Void

    @State private var dragPosition: CGFloat?
    @State private var isHovered = false

    private static let width: CGFloat = 8

    var body: some View {
        let isActive = isHovered || dragPosition != nil

        RoundedRectangle(cornerRadius: 3)
            .fill(isActive ? EditorTheme.accent : EditorTheme.primary)
            .overlay {
                Capsule()
                    .fill(.black.opacity(0.45))
                    .frame(width: 2, height: 14)
            }
            .shadow(color: .black.opacity(0.4), radius: 2)
            .frame(width: Self.width)
            .offset(x: (dragPosition ?? position) - (edge == .leading ? 0 : Self.width))
            .pointerStyle(.frameResize(position: edge == .leading ? .leading : .trailing))
            .onHover { isHovered = $0 }
            .editorMotion(.snappy(duration: 0.18), value: isActive)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { dragPosition = $0.location.x }
                    .onEnded { value in
                        dragPosition = nil
                        onDrop(value.location.x)
                    }
            )
    }
}
