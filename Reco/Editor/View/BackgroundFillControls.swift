//
//  BackgroundFillControls.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import SwiftUI

/// What the chosen kind of background is made of: a gradient's presets and colors, a color, or a picture
/// with the system's wallpapers and its blur.
struct BackgroundFillControls: View {
    @Bindable var viewModel: EditorViewModel
    @Binding var choosesImage: Bool

    var body: some View {
        Group {
            switch viewModel.canvas.background {
            case .gradient:
                SwatchGrid(
                    values: GradientPreset.all, selection: viewModel.canvas.gradientPreset?.id, name: \.name,
                    pick: { viewModel.applyGradient($0) },
                    swatch: { preset in
                        LinearGradient(
                            colors: [Color(cgColor: preset.start.cgColor), Color(cgColor: preset.end.cgColor)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                )
                HStack {
                    ColorPicker("Start", selection: $viewModel.canvas.gradientStart.cgColor, supportsOpacity: false)
                    Spacer()
                    ColorPicker("End", selection: $viewModel.canvas.gradientEnd.cgColor, supportsOpacity: false)
                }
            case .color:
                ColorPicker("Color", selection: $viewModel.canvas.color.cgColor, supportsOpacity: false)
            case .image:
                if !viewModel.wallpapers.isEmpty {
                    SwatchGrid(
                        values: viewModel.wallpapers, selection: viewModel.wallpapers.first(where: viewModel.isBackground)?.id,
                        name: \.name, pick: { viewModel.setBackgroundImage($0.url) },
                        swatch: { wallpaper in
                            Image(decorative: wallpaper.thumbnail, scale: 2)
                                .resizable()
                        }
                    )
                }
                Button {
                    choosesImage = true
                } label: {
                    Label("Choose Image…", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                InspectorSlider("Blur", value: $viewModel.canvas.backgroundBlur, in: 0...1, defaultValue: 0) {
                    $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
                }
            case .transparent:
                EmptyView()
            }
        }
        .transition(.opacity)
    }
}
