//
//  CameraStyleCard.swift
//  Reco
//

import SwiftUI

/// The camera bubble's place, shape and timing.
struct CameraStyleCard: View {
    @Bindable var viewModel: EditorViewModel
    let footage: CameraFootage

    /// The footage's first frame, for the crop pad.
    @State private var picture: CGImage?

    private static let pictureSize = CGSize(width: 640, height: 640)

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Bubble")
            InspectorCard {
                VStack(spacing: 0) {
                    HStack {
                        Text("Corner")
                        Spacer()
                        ForEach(CameraOverlayStyle.Corner.allCases, id: \.self) { corner in
                            Button(corner.title, systemImage: corner.symbol) {
                                viewModel.moveCameraBubble(to: corner)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                    .inspectorCardRow()
                    InspectorHairline()
                    InspectorSlider(
                        "Size", value: $viewModel.cameraStyle.size, in: CameraOverlayStyle.sizes, defaultValue: CameraOverlayStyle().size
                    ) { Text($0, format: .percent.precision(.fractionLength(0))) }
                    .inspectorCardRow()
                    InspectorHairline()
                    InspectorSlider(
                        "Roundness", value: $viewModel.cameraStyle.roundness, in: 0...1, defaultValue: CameraOverlayStyle().roundness
                    ) { Text($0, format: .percent.precision(.fractionLength(0))) }
                    .inspectorCardRow()
                    InspectorHairline()
                    InspectorSlider(
                        "Shadow", value: $viewModel.cameraStyle.shadow, in: 0...1, defaultValue: CameraOverlayStyle().shadow
                    ) { Text($0, format: .percent.precision(.fractionLength(0))) }
                    .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Mirror", isOn: $viewModel.cameraStyle.isMirrored)
                        .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Shrink During Zooms", isOn: $viewModel.cameraStyle.shrinksDuringZooms)
                        .inspectorCardRow()
                    InspectorHairline()
                    InspectorSlider(
                        "Time Offset", value: $viewModel.cameraStyle.timeOffset, in: CameraOverlayStyle.timeOffsets, defaultValue: 0
                    ) { Text("\($0, format: .number.precision(.fractionLength(2))) s") }
                    .inspectorCardRow()
                }
            }
            InspectorSectionHeader("Crop") {
                if viewModel.cameraStyle.crop != VideoCrop.full {
                    Button("Reset") {
                        viewModel.cameraStyle.crop = VideoCrop.full
                    }
                    .buttonStyle(.borderless)
                    .font(.theme(.caption))
                }
            }
            InspectorCard {
                RegionPad(
                    image: picture,
                    videoSize: footage.displaySize,
                    regions: Binding { [viewModel.cameraStyle.crop] } set: { viewModel.cameraStyle.crop = VideoCrop.clamped($0[0]) },
                    selection: .constant(0),
                    minimumSize: VideoCrop.minimumSize,
                    label: "Camera Crop"
                )
                .padding(6)
            }
        }
        .disabled(!viewModel.cameraStyle.isEnabled)
        .task(id: footage.url) {
            picture = await CameraFootageStore.picture(of: footage, maximumSize: Self.pictureSize)
        }
    }
}
