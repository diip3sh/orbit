//
//  BackgroundFillControls.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import SwiftUI

/// What the chosen kind of background is made of: a gradient's presets and colors, a color, or a picture
/// with the system's wallpapers and its blur. Bound to the style, so the editor's canvas and the screenshot
/// background in Settings share it.
struct BackgroundFillControls: View {
    @Binding var canvas: CanvasStyle

    /// The system's wallpapers to offer, once read.
    let wallpapers: [SystemWallpaper]

    /// The file the canvas's picture was read from, which rings its wallpaper.
    let imageURL: URL?

    /// Makes the picture at a URL the background: the owner keeps a bookmark to it.
    let setImage: (URL) -> Void

    @Binding var choosesImage: Bool

    var body: some View {
        Group {
            switch canvas.background {
            case .gradient:
                SwatchGrid(
                    values: GradientPreset.all, selection: canvas.gradientPreset?.id, name: \.name,
                    pick: { canvas.apply($0) },
                    swatch: { preset in
                        LinearGradient(
                            colors: [Color(cgColor: preset.start.cgColor), Color(cgColor: preset.end.cgColor)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    }
                )
                HStack {
                    ColorPicker("Start", selection: $canvas.gradientStart.cgColor, supportsOpacity: false)
                    Spacer()
                    ColorPicker("End", selection: $canvas.gradientEnd.cgColor, supportsOpacity: false)
                }
            case .color:
                ColorPicker("Color", selection: $canvas.color.cgColor, supportsOpacity: false)
            case .image:
                if !wallpapers.isEmpty {
                    SwatchGrid(
                        values: wallpapers, selection: wallpapers.first { $0.url == imageURL }?.id,
                        name: \.name, pick: { setImage($0.url) },
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
                InspectorSlider("Blur", value: $canvas.backgroundBlur, in: 0...1, defaultValue: 0) {
                    $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
                }
            case .transparent:
                EmptyView()
            }
        }
        .transition(.opacity)
    }
}

/// The background's kind and fill, and the video's padding, corners, shadow and border: the canvas's controls
/// after its shape, shared by the editor's Background tab and the screenshot background in Settings.
struct CanvasStyleControls: View {
    @Binding var canvas: CanvasStyle
    let wallpapers: [SystemWallpaper]
    let imageURL: URL?
    let setImage: (URL) -> Void
    @Binding var choosesImage: Bool

    var body: some View {
        InspectorField("Background") {
            TilePicker(selection: $canvas.background, values: CanvasStyle.Background.allCases) { background in
                switch background {
                case .gradient: "Gradient"
                case .color: "Color"
                case .image: "Image"
                case .transparent: "Clear"
                }
            } picture: { background in
                BackgroundSwatch(background: background, canvas: canvas)
            }
        }

        BackgroundFillControls(canvas: $canvas, wallpapers: wallpapers, imageURL: imageURL, setImage: setImage, choosesImage: $choosesImage)

        InspectorSlider("Padding", value: $canvas.padding, in: 0...0.25, defaultValue: CanvasStyle().padding) {
            Text($0, format: .percent.precision(.fractionLength(0)))
        }
        InspectorSlider("Corners", value: $canvas.cornerRadius, in: 0...0.05, defaultValue: CanvasStyle().cornerRadius) {
            Text($0, format: .percent.precision(.fractionLength(1)))
        }
        InspectorSlider("Shadow", value: $canvas.shadow, in: 0...1, defaultValue: CanvasStyle().shadow) {
            Text($0, format: .percent.precision(.fractionLength(0)))
        }
        // The border grows into the padding, so without any there's no room for it
        let hasNoRoomForBorder = canvas.padding == 0
        Group {
            InspectorSlider("Border", value: $canvas.borderWidth, in: 0...0.02, defaultValue: 0) {
                $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(1)))
            }
            if canvas.borderWidth > 0 {
                ColorPicker("Border Color", selection: $canvas.borderColor.cgColor, supportsOpacity: false)
            }
        }
        .disabled(hasNoRoomForBorder)
        // Text in ink doesn't dim by itself when disabled
        .opacity(hasNoRoomForBorder ? 0.4 : 1)
    }
}
