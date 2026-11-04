//
//  CameraBubbleHandle.swift
//  Reco
//

import SwiftUI

/// What drags the camera bubble on the stage: an invisible square over it, outlined under the pointer. The bubble
/// itself is in the video.
struct CameraBubbleHandle: View {
    let viewModel: EditorViewModel

    private static let space = "CameraBubbleHandle"

    @State private var size: CGSize = .zero
    @State private var dragStart: CGPoint?
    @State private var isHovered = false

    var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                if let rect = viewModel.cameraBubbleRect(inViewOf: size) {
                    let roundness = viewModel.cameraStyle.roundness
                    RoundedRectangle(cornerRadius: roundness * rect.width / 2)
                        .strokeBorder(EditorTheme.accent.opacity(isHovered || dragStart != nil ? 1 : 0), lineWidth: 2)
                        .contentShape(.rect(cornerRadius: roundness * rect.width / 2))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .onHover { isHovered = $0 }
                        // In the stage's space: the square moves under the pointer, which would skew its own space
                        .gesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                                .onChanged { value in
                                    let start = dragStart ?? viewModel.cameraStyle.center
                                    dragStart = start
                                    viewModel.dragCameraBubble(from: start, by: value.translation, viewSize: size)
                                }
                                .onEnded { _ in dragStart = nil }
                        )
                        .accessibilityLabel("Camera Bubble")
                }
            }
            .coordinateSpace(.named(Self.space))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
    }
}
