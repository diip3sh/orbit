//
//  PinView.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// A pinned screenshot: fills its panel, drags it anywhere, shows a close button on hover. It
/// appears from, and closes back into, its bottom-left corner, where the card it came from was.
struct PinView: View {

    let image: CGImage
    let presence: PanelPresence
    let close: () -> Void

    @State private var isHovering = false

    var body: some View {
        Image(image, scale: 1, label: Text("Pinned Screenshot"))
            .resizable()
            .scaledToFit()
            .gesture(WindowDragGesture())
            .overlay(alignment: .topLeading) {
                if isHovering {
                    Button("Close", systemImage: "xmark.circle.fill", action: close)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        .imageScale(.large)
                        .help("Close")
                        .padding(6)
                        .transition(.opacity)
                }
            }
            .editorMotion(value: isHovering)
            .onHover { isHovering = $0 }
            .panelPresentation(isPresented: presence.isShown, anchor: .bottomLeading)
            .allowsWindowActivationEvents(true)
    }
}
