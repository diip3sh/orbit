//
//  InspectorResizeHandle.swift
//  Reco
//

import SwiftUI

/// The inspector panel's leading edge: dragging it makes the panel wider or narrower, between the limits
/// the system's inspector column had.
struct InspectorResizeHandle: View {
    /// The panel's width, a `Double` because `@AppStorage` has no `CGFloat`.
    @Binding var width: Double

    /// The panel's width where the drag started, which each move is measured from.
    @State private var dragStart: Double?

    static let range: ClosedRange<Double> = 300...460

    var body: some View {
        Color.clear
            .frame(width: 14)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .onHover { isInside in
                if isInside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let start = dragStart ?? width
                        dragStart = start
                        width = min(max(start - Double(value.translation.width), Self.range.lowerBound), Self.range.upperBound)
                    }
                    .onEnded { _ in
                        dragStart = nil
                    }
            )
    }
}
