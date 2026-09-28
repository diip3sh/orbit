//
//  ZoomFocusPad.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The frame with a zoom's view outlined on it. Dragging moves the view's centre.
struct ZoomFocusPad: View {

    /// The frame, or `nil` while the filmstrip loads.
    let image: CGImage?

    let videoSize: CGSize
    let scale: Double

    /// As fractions of the video's width and height from its top-left corner.
    @Binding var center: CGPoint

    @State private var size: CGSize = .zero

    var body: some View {
        let shown = ZoomSegment.clamped(center, scale: scale)
        let viewSize = CGSize(width: size.width / scale, height: size.height / scale)

        ZStack(alignment: .topLeading) {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
            } else {
                Color.black
            }
            Rectangle()
                .strokeBorder(.yellow, lineWidth: 2)
                .frame(width: viewSize.width, height: viewSize.height)
                .offset(x: shown.x * size.width - viewSize.width / 2, y: shown.y * size.height - viewSize.height / 2)
        }
        .aspectRatio(videoSize, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 4))
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard size.width > 0, size.height > 0 else { return }
                    center = CGPoint(x: value.location.x / size.width, y: value.location.y / size.height)
                }
        )
        .accessibilityLabel("Zoom focus")
    }
}
