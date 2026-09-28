//
//  QuickAccessView.swift
//  BetterCapture
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// The floating thumbnail card: image, hover controls, drag source.
struct QuickAccessView: View {

    let image: CGImage
    let fileURL: URL
    let controller: QuickAccessController

    @State private var isHovering = false

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .frame(width: QuickAccessController.cardSize.width, height: QuickAccessController.cardSize.height)
            .background(.regularMaterial)
            .overlay {
                if isHovering {
                    QuickAccessHoverControls(controller: controller)
                }
            }
            .clipShape(.rect(cornerRadius: 10))
            .onHover { hovering in
                isHovering = hovering
                controller.setHovering(hovering)
            }
            .onDrag {
                NSItemProvider(object: fileURL as NSURL)
            }
    }
}

/// Close, Copy and Show in Finder, dimming the thumbnail underneath so they read on any image.
private struct QuickAccessHoverControls: View {

    let controller: QuickAccessController

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)

            VStack {
                HStack {
                    Button("Close", systemImage: "xmark", action: controller.dismiss)
                        .labelStyle(.iconOnly)
                    Spacer()
                }
                Spacer()
                HStack {
                    Button("Copy", systemImage: "doc.on.doc", action: controller.copy)
                    Button("Show in Finder", systemImage: "folder", action: controller.showInFinder)
                }
                Spacer()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}
