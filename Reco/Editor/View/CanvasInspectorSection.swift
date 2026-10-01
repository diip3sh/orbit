//
//  CanvasInspectorSection.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The canvas's shape, background, padding, corners and shadow.
struct CanvasInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    @State private var choosesBackgroundImage = false

    var body: some View {
        let videoSize = viewModel.source?.naturalSize ?? CGSize(width: 16, height: 9)

        InspectorSection("Canvas") {
            InspectorField("Aspect Ratio") {
                TilePicker(selection: $viewModel.canvas.aspect, values: CanvasStyle.Aspect.allCases) { aspect in
                    aspect == .source ? "Original" : LocalizedStringKey(aspect.rawValue)
                } picture: { aspect in
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(lineWidth: 1.5)
                        .aspectRatio(aspect.ratio ?? videoSize.width / max(videoSize.height, 1), contentMode: .fit)
                }
            }

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

            Group {
                switch viewModel.canvas.background {
                case .gradient:
                    HStack {
                        ColorPicker("Start", selection: $viewModel.canvas.gradientStart.cgColor, supportsOpacity: false)
                        Spacer()
                        ColorPicker("End", selection: $viewModel.canvas.gradientEnd.cgColor, supportsOpacity: false)
                    }
                case .color:
                    ColorPicker("Color", selection: $viewModel.canvas.color.cgColor, supportsOpacity: false)
                case .image:
                    Button {
                        choosesBackgroundImage = true
                    } label: {
                        Label("Choose Image…", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                case .transparent:
                    EmptyView()
                }
            }
            .transition(.opacity)

            InspectorSlider("Padding", value: $viewModel.canvas.padding, in: 0...0.25) {
                Text($0, format: .percent.precision(.fractionLength(0)))
            }
            InspectorSlider("Corners", value: $viewModel.canvas.cornerRadius, in: 0...0.05) {
                Text($0, format: .percent.precision(.fractionLength(1)))
            }
            InspectorSlider("Shadow", value: $viewModel.canvas.shadow, in: 0...1) {
                Text($0, format: .percent.precision(.fractionLength(0)))
            }
        } footer: {
            if viewModel.canvas.background == .transparent {
                Text("Only ProRes 4444 exports keep the background transparent; other formats make it black.")
            }
        }
        .editorMotion(value: viewModel.canvas.background)
        .fileImporter(isPresented: $choosesBackgroundImage, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                viewModel.setBackgroundImage(url)
            }
        }
    }
}
