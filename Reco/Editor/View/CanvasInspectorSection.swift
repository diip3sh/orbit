//
//  CanvasInspectorSection.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The canvas's shape, background, padding, corners, shadow and border, in one section with no title.
struct CanvasInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    @State private var choosesBackgroundImage = false

    var body: some View {
        let videoSize = viewModel.videoSize ?? CGSize(width: 16, height: 9)

        InspectorSection(nil) {
            InspectorField("Aspect Ratio") {
                TilePicker(selection: $viewModel.canvas.aspect, values: CanvasStyle.Aspect.allCases) { aspect in
                    aspect == .source ? "Original" : LocalizedStringKey(aspect.rawValue)
                } picture: { aspect in
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(lineWidth: 1.5)
                        .aspectRatio(aspect.ratio ?? videoSize.width / max(videoSize.height, 1), contentMode: .fit)
                }
            }
            // In the recording's own shape the video fills the frame either way
            if viewModel.canvas.aspect != .source {
                InspectorField("Video") {
                    SegmentedChoice(selection: $viewModel.canvas.fillsFrame, options: [(false, "Fit"), (true, "Fill")])
                }
                .transition(.opacity)
            }

            CropField(viewModel: viewModel)

            CanvasStyleControls(
                canvas: $viewModel.canvas, wallpapers: viewModel.wallpapers, imageURL: viewModel.backgroundImageURL,
                setImage: viewModel.setBackgroundImage, choosesImage: $choosesBackgroundImage
            )
        } footer: {
            if viewModel.canvas.background == .transparent {
                Text("Only ProRes 4444 exports keep the background transparent; other formats make it black.")
            }
        }
        .editorMotion(value: viewModel.canvas.background)
        .editorMotion(value: viewModel.canvas.aspect == .source)
        .task { await viewModel.loadWallpapers() }
        .fileImporter(isPresented: $choosesBackgroundImage, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                viewModel.setBackgroundImage(url)
            }
        }
    }
}

/// The canvas's crop: the pad on the frame at the playhead, and Reset once something is cropped.
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
                        .font(.theme(.caption))
                        .transition(.opacity)
                }
            }
            if let videoSize = viewModel.source?.naturalSize {
                RegionPad(
                    image: viewModel.thumbnail(at: viewModel.playheadSourceTime),
                    videoSize: videoSize,
                    regions: Binding { [viewModel.crop] } set: { viewModel.crop = $0[0] },
                    selection: .constant(0),
                    minimumSize: VideoCrop.minimumSize,
                    label: "Crop",
                    onEnd: viewModel.cropDidSettle
                )
            }
        }
        .editorMotion(value: viewModel.crop == VideoCrop.full)
    }
}
