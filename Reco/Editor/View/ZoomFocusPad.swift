//
//  ZoomFocusPad.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The frame with a zoom's view outlined on it and the rest dimmed. Dragging moves the view's centre:
/// grabbed inside the outline, it keeps the offset from where it was grabbed; pressed outside, the
/// centre jumps to the pointer.
struct ZoomFocusPad: View {

    /// The frame, or `nil` while the filmstrip loads.
    let image: CGImage?

    let videoSize: CGSize
    let scale: Double

    /// The part of the video shown at 1×, as fractions of it (``CanvasLayout/baseView``), which the zoom magnifies.
    var baseView = CameraPath.wholeVideo

    /// As fractions of the video's width and height from its top-left corner.
    @Binding var center: CGPoint

    @State private var size: CGSize = .zero

    /// From the outline's centre to where it was grabbed, in points; zero after a press outside.
    @State private var grabOffset: CGSize?

    var body: some View {
        let shown = ZoomSegment.clamped(center, scale: scale, in: baseView)
        let viewSize = CGSize(width: size.width * baseView.width / scale, height: size.height * baseView.height / scale)
        let view = CGRect(
            x: shown.x * size.width - viewSize.width / 2, y: shown.y * size.height - viewSize.height / 2,
            width: viewSize.width, height: viewSize.height
        )

        ZStack(alignment: .topLeading) {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
            } else {
                EditorTheme.softHairline
            }
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.5)))
                context.blendMode = .clear
                context.fill(Path(view), with: .color(.black))
            }
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(EditorTheme.accent, lineWidth: 2)
                .frame(width: view.width, height: view.height)
                .offset(x: view.minX, y: view.minY)
        }
        .aspectRatio(videoSize, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(EditorTheme.hairline)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .pointerStyle(.grabIdle)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard size.width > 0, size.height > 0 else { return }
                    let offset = grabOffset ?? (view.contains(value.startLocation)
                        ? CGSize(width: value.startLocation.x - view.midX, height: value.startLocation.y - view.midY)
                        : .zero)
                    grabOffset = offset
                    center = CGPoint(
                        x: (value.location.x - offset.width) / size.width,
                        y: (value.location.y - offset.height) / size.height
                    )
                }
                .onEnded { _ in grabOffset = nil }
        )
        .accessibilityLabel("Zoom focus")
    }
}
