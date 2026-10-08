//
//  CropPad.swift
//  Reco
//

import SwiftUI

/// The canvas inspector's crop: the pad on the frame at the playhead, and Reset once something is cropped.
struct CropField: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            HStack {
                Text("Crop")
                Spacer()
                if viewModel.crop != VideoCrop.full {
                    Button("Reset", action: viewModel.resetCrop)
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .transition(.opacity)
                }
            }
            if let videoSize = viewModel.source?.naturalSize {
                CropPad(
                    image: viewModel.thumbnail(at: viewModel.playheadSourceTime),
                    videoSize: videoSize,
                    crop: $viewModel.crop,
                    onEnd: viewModel.cropDidSettle
                )
            }
        }
        .editorMotion(value: viewModel.crop == VideoCrop.full)
    }
}

/// The whole frame with the crop outlined on it and the rest dimmed. Dragging near an edge or a corner moves
/// those edges, inside moves the crop, 1:1 from where it was grabbed.
struct CropPad: View {

    /// The frame, or `nil` while the filmstrip loads.
    let image: CGImage?

    let videoSize: CGSize

    /// As fractions of the video from its top-left corner.
    @Binding var crop: CGRect

    /// A drag has ended.
    let onEnd: () -> Void

    /// How close to an edge, in points, a press takes that edge.
    private static let edgeReach: CGFloat = 10

    private static let corners: [Alignment] = [.topLeading, .topTrailing, .bottomLeading, .bottomTrailing]

    @State private var size: CGSize = .zero

    /// The crop and the edges a drag moves, from when it started.
    @State private var drag: (start: CGRect, edges: VideoCrop.Edges)?

    var body: some View {
        let outline = CGRect(
            x: crop.minX * size.width, y: crop.minY * size.height, width: crop.width * size.width, height: crop.height * size.height
        )

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
                context.fill(Path(outline), with: .color(.black))
            }
            Rectangle()
                .strokeBorder(EditorTheme.accent, lineWidth: 2)
                .overlay {
                    ForEach(Self.corners.indices, id: \.self) { corner in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(EditorTheme.accent)
                            .frame(width: 8, height: 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Self.corners[corner])
                    }
                }
                .frame(width: outline.width, height: outline.height)
                .offset(x: outline.minX, y: outline.minY)
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
                    let current = drag ?? (crop, Self.edges(at: value.startLocation, of: outline))
                    drag = current
                    guard !current.edges.isEmpty else { return }
                    crop = VideoCrop.dragged(
                        current.start, edges: current.edges,
                        by: CGSize(width: value.translation.width / size.width, height: value.translation.height / size.height)
                    )
                }
                .onEnded { _ in
                    drag = nil
                    onEnd()
                }
        )
        .accessibilityLabel("Crop")
    }

    /// The edges within ``edgeReach`` of `point`, all four inside the outline away from them, none outside it.
    private static func edges(at point: CGPoint, of outline: CGRect) -> VideoCrop.Edges {
        let reach = outline.insetBy(dx: -edgeReach, dy: -edgeReach)
        guard reach.contains(point) else { return [] }
        var edges: VideoCrop.Edges = []
        if abs(point.x - outline.minX) < edgeReach { edges.insert(.left) }
        if abs(point.x - outline.maxX) < edgeReach { edges.insert(.right) }
        if abs(point.y - outline.minY) < edgeReach { edges.insert(.top) }
        if abs(point.y - outline.maxY) < edgeReach { edges.insert(.bottom) }
        // A crop narrower than twice the reach would take both sides; the nearer one wins
        if edges.isSuperset(of: [.left, .right]) {
            edges.remove(abs(point.x - outline.minX) < abs(point.x - outline.maxX) ? .right : .left)
        }
        if edges.isSuperset(of: [.top, .bottom]) {
            edges.remove(abs(point.y - outline.minY) < abs(point.y - outline.maxY) ? .bottom : .top)
        }
        return edges.isEmpty && outline.contains(point) ? .all : edges
    }
}
