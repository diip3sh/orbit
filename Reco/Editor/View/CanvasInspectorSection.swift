//
//  CanvasInspectorSection.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// The Background tab: the canvas's shape and the video's fit, the crop, the background's kind and fill,
/// and the frame's padding, corners, shadow and border. Each group is a card under a small-caps title;
/// the frame's sliders are bars of their own.
struct CanvasInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    @State private var choosesBackgroundImage = false

    var body: some View {
        let videoSize = viewModel.videoSize ?? CGSize(width: 16, height: 9)

        VStack(spacing: EditorTheme.largeSpacing) {
            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                InspectorSectionHeader("Canvas")
                InspectorCard {
                    VStack(spacing: 0) {
                        GlyphSegmentedPicker(
                            selection: $viewModel.canvas.aspect,
                            options: CanvasStyle.Aspect.allCases.map {
                                ($0, $0 == .source ? "Original" : LocalizedStringKey($0.rawValue))
                            }
                        ) { aspect in
                            RoundedRectangle(cornerRadius: 1.5)
                                .strokeBorder(lineWidth: 1)
                                .aspectRatio(aspect.ratio ?? videoSize.width / max(videoSize.height, 1), contentMode: .fit)
                                .frame(height: 9)
                        }
                        .padding(6)

                        // In the recording's own shape the video fills the frame either way
                        if viewModel.canvas.aspect != .source {
                            HStack {
                                Text("Video")
                                Spacer()
                                SegmentedChoice(
                                    selection: $viewModel.canvas.fillsFrame,
                                    options: [(false, "Fit"), (true, "Fill")],
                                    trackFill: EditorTheme.panel
                                )
                                .fixedSize()
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 2)
                            .padding(.bottom, 11)
                            .transition(.opacity)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                InspectorSectionHeader("Crop") {
                    if viewModel.crop != VideoCrop.full {
                        Button("Reset", action: viewModel.resetCrop)
                            .buttonStyle(.borderless)
                            .font(.theme(.caption))
                            .transition(.opacity)
                    }
                }
                InspectorCard {
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
                        .padding(6)
                    }
                }
                .editorMotion(value: viewModel.crop == VideoCrop.full)
            }

            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                InspectorSectionHeader("Background")
                InspectorCard {
                    VStack(spacing: 0) {
                        GlyphSegmentedPicker(
                            selection: $viewModel.canvas.background,
                            options: CanvasStyle.Background.allCases.map { ($0, name(of: $0)) }
                        ) { background in
                            BackgroundSwatch(background: background, canvas: viewModel.canvas, width: 15, height: 10)
                        }
                        .padding(6)

                        BackgroundFillCard(
                            canvas: $viewModel.canvas, wallpapers: viewModel.wallpapers,
                            imageURL: viewModel.backgroundImageURL, setImage: viewModel.setBackgroundImage,
                            choosesImage: $choosesBackgroundImage
                        )
                    }
                }
                if viewModel.canvas.background == .transparent {
                    InspectorNote("Only ProRes 4444 exports keep the background transparent; other formats make it black.")
                }
            }

            VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
                InspectorSectionHeader("Frame")
                SliderBar("Padding", value: $viewModel.canvas.padding, in: 0...0.25) {
                    Text($0, format: .percent.precision(.fractionLength(0)))
                }
                SliderBar("Corners", value: $viewModel.canvas.cornerRadius, in: 0...0.05) {
                    Text($0, format: .percent.precision(.fractionLength(1)))
                }
                SliderBar("Shadow", value: $viewModel.canvas.shadow, in: 0...1) {
                    Text($0, format: .percent.precision(.fractionLength(0)))
                }
                // The border grows into the padding, so without any there's no room for it
                let hasNoRoomForBorder = viewModel.canvas.padding == 0
                Group {
                    SliderBar("Border", value: $viewModel.canvas.borderWidth, in: 0...0.02) {
                        $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(1)))
                    }
                    if viewModel.canvas.borderWidth > 0 {
                        InspectorCard {
                            InspectorColorRow("Border Color") {
                                ColorPicker("Border Color", selection: $viewModel.canvas.borderColor.cgColor, supportsOpacity: false)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                        }
                        .transition(.opacity)
                    }
                }
                .disabled(hasNoRoomForBorder)
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

    private func name(of background: CanvasStyle.Background) -> LocalizedStringKey {
        switch background {
        case .gradient: "Gradient"
        case .color: "Color"
        case .image: "Image"
        case .transparent: "Clear"
        }
    }
}

/// What the chosen kind of background is made of, inside the Background card: a gradient's presets and
/// its two colors, a color, or a picture with the system's wallpapers and its blur. The editor's version
/// of `BackgroundFillControls`, which Settings keeps for the screenshot background.
private struct BackgroundFillCard: View {
    @Binding var canvas: CanvasStyle
    let wallpapers: [SystemWallpaper]
    let imageURL: URL?
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
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
                InspectorHairline()
                InspectorColorRow("Start Color") {
                    ColorPicker("Start", selection: $canvas.gradientStart.cgColor, supportsOpacity: false)
                        .help("Start color")
                }
                .inspectorCardRow()
                InspectorHairline()
                InspectorColorRow("End Color") {
                    ColorPicker("End", selection: $canvas.gradientEnd.cgColor, supportsOpacity: false)
                        .help("End color")
                }
                .inspectorCardRow()
            case .color:
                InspectorHairline()
                InspectorColorRow("Color") {
                    ColorPicker("Color", selection: $canvas.color.cgColor, supportsOpacity: false)
                }
                .inspectorCardRow()
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
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }
                Button {
                    choosesImage = true
                } label: {
                    Label("Choose Image…", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.editorSecondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                InspectorSlider("Blur", value: $canvas.backgroundBlur, in: 0...1, defaultValue: 0) {
                    $0 == 0 ? Text("Off") : Text($0, format: .percent.precision(.fractionLength(0)))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            case .transparent:
                EmptyView()
            }
        }
        .transition(.opacity)
    }
}
