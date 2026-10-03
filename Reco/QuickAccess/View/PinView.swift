//
//  PinView.swift
//  Reco
//
//  Created by Diip3sh on 29.09.26.
//

import SwiftUI

/// A pinned screenshot: fills its panel with the card's rounded corners, drags it anywhere, shows the card's
/// close button on hover. It appears from, and closes back into, its bottom-left corner, where the card it came
/// from was.
struct PinView: View {

    let image: CGImage
    let presence: PanelPresence
    let close: () -> Void

    @State private var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)

        Image(image, scale: 1, label: Text("Pinned Screenshot"))
            .resizable()
            .scaledToFit()
            .clipShape(shape)
            // Keeps the edge visible where the shot meets a background of the same colour
            .overlay { shape.strokeBorder(.white.opacity(0.15)) }
            .gesture(WindowDragGesture())
            .overlay(alignment: .topLeading) {
                Button(action: close) { Label { Text("Close") } icon: { LineIcon(.iconsaxClose) } }
                    .labelStyle(.iconOnly)
                    .buttonStyle(CornerButtonStyle())
                    .help("Close")
                    .padding(6)
                    .opacity(isHovering ? 1 : 0)
            }
            .editorMotion(EditorTheme.quickMotion, value: isHovering)
            .onHover { isHovering = $0 }
            .panelPresentation(isPresented: presence.isShown, anchor: .bottomLeading)
            .allowsWindowActivationEvents(true)
    }
}
