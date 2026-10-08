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

            CropField(viewModel: viewModel)

            InspectorField("Background") {
                TilePicker(selection: $viewModel.canvas.background, values: CanvasStyle.Background.allCases) { background in
                    switch background {
                    case .gradient: "Gradient"
                    case .color: "Color"
                    case .image: "Image"
                    case .transparent: "Clear"
                    }
                } picture: { background in
                    BackgroundSwatch(background: background, canvas: viewModel.canvas)
                }
            }

            BackgroundFillControls(viewModel: viewModel, choosesImage: $choosesBackgroundImage)

            InspectorSlider("Padding", value: $viewModel.canvas.padding, in: 0...0.25, defaultValue: CanvasStyle().padding) {
                Text($0, format: .percent.precision(.fractionLength(0)))
            }
            InspectorSlider("Corners", value: $viewModel.canvas.cornerRadius, in: 0...0.05, defaultValue: CanvasStyle().cornerRadius) {
                Text($0, format: .percent.precision(.fractionLength(1)))
            }
            InspectorSlider("Shadow", value: $viewModel.canvas.shadow, in: 0...1, defaultValue: CanvasStyle().shadow) {
                Text($0, format: .percent.precision(.fractionLength(0)))
            }
            // The border grows into the padding, so without any there's no room for it
            let hasNoRoomForBorder = viewModel.canvas.padding == 0
            Group {
                InspectorSlider("Border", value: $viewModel.canvas.borderWidth, in: 0...0.02, defaultValue: 0) {
                    $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(1)))
                }
                if viewModel.canvas.borderWidth > 0 {
                    ColorPicker("Border Color", selection: $viewModel.canvas.borderColor.cgColor, supportsOpacity: false)
                }
            }
            .disabled(hasNoRoomForBorder)
            // Text in ink doesn't dim by itself when disabled
            .opacity(hasNoRoomForBorder ? 0.4 : 1)
        } footer: {
            if viewModel.canvas.background == .transparent {
                Text("Only ProRes 4444 exports keep the background transparent; other formats make it black.")
            }
        }
        .editorMotion(value: viewModel.canvas.background)
        .task { await viewModel.loadWallpapers() }
        .fileImporter(isPresented: $choosesBackgroundImage, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                viewModel.setBackgroundImage(url)
            }
        }
    }
}
