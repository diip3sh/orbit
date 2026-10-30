//
//  OverlayHandle.swift
//  Reco
//

import SwiftUI

/// What moves the selected overlay on the stage: an outline to drag it by, and a grip on each corner, or on each end of an
/// arrow. The overlay itself is in the video. Gone during playback, which shows the video as it will look.
struct OverlayHandle: View {
    let viewModel: EditorViewModel

    private static let space = "OverlayHandle"

    /// How far past a grip's dot a press still takes it, in points.
    private static let gripReach: CGFloat = 5

    private static let gripDiameter: CGFloat = 10

    @State private var size: CGSize = .zero

    /// The overlay as it was when the drag started.
    @State private var dragStart: VideoOverlay?

    private struct Corner: Identifiable {
        let edges: RegionDrag.Edges
        let point: CGPoint
        let position: FrameResizePosition

        var id: Int { edges.rawValue }
    }

    private static let corners = [
        Corner(edges: [.left, .top], point: CGPoint(x: 0, y: 0), position: .topLeading),
        Corner(edges: [.right, .top], point: CGPoint(x: 1, y: 0), position: .topTrailing),
        Corner(edges: [.left, .bottom], point: CGPoint(x: 0, y: 1), position: .bottomLeading),
        Corner(edges: [.right, .bottom], point: CGPoint(x: 1, y: 1), position: .bottomTrailing)
    ]

    var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                if let overlay = viewModel.selectedOverlay, !viewModel.playback.isPlaying, let rect = viewModel.overlayRect(inViewOf: size) {
                    Rectangle()
                        .strokeBorder(EditorTheme.accent, lineWidth: overlay.arrowStyle == nil ? 1.5 : 1)
                        .contentShape(.rect)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .pointerStyle(dragStart == nil ? .grabIdle : .grabActive)
                        .gesture(frameDrag(of: overlay, edges: .all))
                        .accessibilityLabel("Overlay")

                    if let arrow = overlay.arrowStyle {
                        grip("Arrow Tail", at: arrow.start, in: rect)
                            .gesture(arrowDrag(of: overlay, movingTip: false))
                        grip("Arrow Tip", at: arrow.end, in: rect)
                            .gesture(arrowDrag(of: overlay, movingTip: true))
                    } else {
                        ForEach(Self.corners) { corner in
                            grip("Resize Overlay", at: corner.point, in: rect)
                                .pointerStyle(.frameResize(position: corner.position))
                                .gesture(frameDrag(of: overlay, edges: corner.edges))
                        }
                    }
                }
            }
            // The handles move under the pointer, which would skew their own space
            .coordinateSpace(.named(Self.space))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }

    /// A dot at `point`, a fraction of `rect`.
    private func grip(_ label: LocalizedStringKey, at point: CGPoint, in rect: CGRect) -> some View {
        Circle()
            .fill(EditorTheme.accent)
            .stroke(.white, lineWidth: 1)
            .frame(width: Self.gripDiameter, height: Self.gripDiameter)
            .padding(Self.gripReach)
            .contentShape(.circle)
            .offset(
                x: rect.minX + point.x * rect.width - Self.gripDiameter / 2 - Self.gripReach,
                y: rect.minY + point.y * rect.height - Self.gripDiameter / 2 - Self.gripReach
            )
            .accessibilityLabel(label)
    }

    private func frameDrag(of overlay: VideoOverlay, edges: RegionDrag.Edges) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = dragStart ?? overlay
                dragStart = start
                viewModel.dragOverlay(from: start, edges: edges, by: value.translation, viewSize: size)
            }
            .onEnded { _ in dragStart = nil }
    }

    private func arrowDrag(of overlay: VideoOverlay, movingTip: Bool) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = dragStart ?? overlay
                dragStart = start
                viewModel.dragArrow(from: start, movingTip: movingTip, by: value.translation, viewSize: size)
            }
            .onEnded { _ in dragStart = nil }
    }
}
