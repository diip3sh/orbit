//
//  ImageOverlayCard.swift
//  Reco
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A picture overlay's picture, with a note when it can't be read, which leaves it out of the video.
struct ImageOverlayCard: View {
    let viewModel: EditorViewModel
    let bookmark: Data

    @State private var picture: CGImage?
    @State private var isUnreadable = false

    private static let pictureSize = 512

    var body: some View {
        InspectorCard {
            VStack(spacing: 0) {
                if let picture {
                    Image(decorative: picture, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .frame(maxWidth: .infinity)
                        .inspectorCardRow()
                    InspectorHairline()
                }
                Button("Replace Picture…", systemImage: "photo", action: choosePicture)
                    .buttonStyle(.borderless)
                    .inspectorCardRow()
            }
        }
        .task(id: bookmark) {
            picture = await BackgroundImageLoader.image(from: bookmark, maximumSize: Self.pictureSize)?.image
            isUnreadable = picture == nil
        }
        if isUnreadable {
            InspectorNote("This picture can't be read, so it's left out of the video. It may have been moved or deleted. Choose it again to bring it back.")
        }
    }

    private func choosePicture() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Picture"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.replaceOverlayImage(from: url) }
        }
    }
}
