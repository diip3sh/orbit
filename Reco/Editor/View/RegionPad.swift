//
//  RegionPad.swift
//  Reco
//

import SwiftUI

/// A frame with rectangles outlined on it and the rest dimmed, for the crop and masks. Dragging near the selected
/// rectangle's edge or corner moves those edges, inside one selects and moves it, 1:1 from where it was grabbed.
struct RegionPad: View {

    /// The frame, or `nil` while the filmstrip loads.
    let image: CGImage?

    let videoSize: CGSize

    /// As fractions of the video from its top-left corner.
    @Binding var regions: [CGRect]

    /// The rectangle with handles, which edge drags resize.
    @Binding var selection: Int

    /// The smallest share of each side a rectangle keeps.
    let minimumSize: Double

    let label: LocalizedStringKey

    /// A drag has ended.
    var onEnd: () -> Void = {}

    /// How close to an edge, in points, a press takes that edge.
    private static let edgeReach: CGFloat = 10

    private static let corners: [Alignment] = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]

    @State private var size: CGSize = .zero

    /// The rectangle being dragged, where it was when the drag started, and the edges it moves.
    private struct Drag {
        var index: Int
        var start: CGRect
        var edges: RegionDrag.Edges
    }

    @State private var drag: Drag?

    var body: some View {
        let outlines = regions.map(outline)

        ZStack(alignment: .topLeading) {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
            } else {
                Color.primary.opacity(0.05)
            }
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.5)))
                context.blendMode = .clear
                for outline in outlines {
                    context.fill(Path(outline), with: .color(.black))
                }
            }
            ForEach(outlines.indices, id: \.self) { index in
                let isSelected = index == selection
                Rectangle()
                    .strokeBorder(isSelected ? EditorTheme.accent : .white.opacity(0.8), lineWidth: isSelected ? 2 : 1)
                    .overlay {
                        if isSelected {
                            ForEach(Self.corners.indices, id: \.self) { corner in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(EditorTheme.accent)
                                    .frame(width: 8, height: 8)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Self.corners[corner])
                            }
                        }
                    }
                    .frame(width: outlines[index].width, height: outlines[index].height)
                    .offset(x: outlines[index].minX, y: outlines[index].minY)
            }
        }
        .aspectRatio(videoSize, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(EditorTheme.hairline)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard size.width > 0, size.height > 0 else { return }
                    guard let current = drag ?? grab(at: value.startLocation, in: outlines) else { return }
                    drag = current
                    regions[current.index] = RegionDrag.dragged(
                        current.start, edges: current.edges,
                        by: CGSize(width: value.translation.width / size.width, height: value.translation.height / size.height),
                        minimumSize: minimumSize
                    )
                }
                .onEnded { _ in
                    guard drag != nil else { return }
                    drag = nil
                    onEnd()
                }
        )
        .accessibilityLabel(Text(label))
    }

    private func outline(of region: CGRect) -> CGRect {
        CGRect(x: region.minX * size.width, y: region.minY * size.height, width: region.width * size.width, height: region.height * size.height)
    }

    /// What a press at `point` drags: the selected rectangle's edges near it, or else the topmost rectangle under it,
    /// which it selects.
    private func grab(at point: CGPoint, in outlines: [CGRect]) -> Drag? {
        if regions.indices.contains(selection) {
            let edges = Self.edges(at: point, of: outlines[selection])
            if !edges.isEmpty {
                return Drag(index: selection, start: regions[selection], edges: edges)
            }
        }
        guard let index = outlines.lastIndex(where: { $0.contains(point) }) else { return nil }
        selection = index
        return Drag(index: index, start: regions[index], edges: .all)
    }

    /// The edges within ``edgeReach`` of `point`, all four inside the outline away from them, none outside it.
    private static func edges(at point: CGPoint, of outline: CGRect) -> RegionDrag.Edges {
        let reach = outline.insetBy(dx: -edgeReach, dy: -edgeReach)
        guard reach.contains(point) else { return [] }
        var edges: RegionDrag.Edges = []
        if abs(point.x - outline.minX) < edgeReach { edges.insert(.left) }
        if abs(point.x - outline.maxX) < edgeReach { edges.insert(.right) }
        if abs(point.y - outline.minY) < edgeReach { edges.insert(.top) }
        if abs(point.y - outline.maxY) < edgeReach { edges.insert(.bottom) }
        // A rectangle narrower than twice the reach would take both sides; the nearer one wins
        if edges.isSuperset(of: [.left, .right]) {
            edges.remove(abs(point.x - outline.minX) < abs(point.x - outline.maxX) ? .right : .left)
        }
        if edges.isSuperset(of: [.top, .bottom]) {
            edges.remove(abs(point.y - outline.minY) < abs(point.y - outline.maxY) ? .bottom : .top)
        }
        return edges.isEmpty && outline.contains(point) ? .all : edges
    }
}
