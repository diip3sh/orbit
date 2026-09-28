//
//  ExportSheet.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// Picks a format, size and frame rate and exports the edited video, with progress. Cancel stops
/// a running export.
struct ExportSheet: View {
    let viewModel: EditorViewModel

    @State private var settings: ExportSettings
    @State private var isExporting = false
    @State private var error: (any Error)?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: EditorViewModel) {
        self.viewModel = viewModel
        // Only ProRes 4444 keeps a transparent background
        _settings = State(initialValue: ExportSettings(format: viewModel.canvas.background == .transparent ? .proRes4444 : .hevc))
    }

    var body: some View {
        let canvasSize = viewModel.exportSize(resolution: nil)
        let frameRate = viewModel.source?.frameRate ?? 0

        Form {
            Section {
                Picker("Format", selection: $settings.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                Picker("Size", selection: $settings.resolution) {
                    Text("Original, \(Self.dimensions(of: canvasSize))").tag(Int?.none)
                    ForEach(ExportSettings.resolutions(below: min(canvasSize.width, canvasSize.height)), id: \.self) { resolution in
                        Text("\(resolution, format: .number.grouping(.never))p, \(Self.dimensions(of: viewModel.exportSize(resolution: resolution)))")
                            .tag(Int?.some(resolution))
                    }
                }
                Picker("Frame Rate", selection: $settings.frameRate) {
                    Text("Original, \(frameRate, format: .number.precision(.fractionLength(0...2))) fps").tag(Int?.none)
                    ForEach(ExportSettings.frameRates(below: frameRate), id: \.self) { rate in
                        Text("\(rate) fps").tag(Int?.some(rate))
                    }
                }
            } footer: {
                if viewModel.canvas.background == .transparent, !settings.format.keepsTransparency {
                    Text("The transparent background exports black. ProRes 4444 keeps it.")
                }
            }
            .disabled(isExporting)

            if let progress = viewModel.exportProgress {
                ProgressView(value: progress)
            }

            if let error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 360)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Export") {
                    error = nil
                    isExporting = true
                }
                .disabled(isExporting)
            }
        }
        // Dismissing the sheet cancels the task, and with it the export
        .task(id: isExporting) {
            guard isExporting else { return }
            do {
                try await viewModel.export(settings)
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error
                isExporting = false
            }
        }
    }

    /// "3840 × 2160"
    private static func dimensions(of size: CGSize) -> String {
        "\(Int(size.width)) × \(Int(size.height))"
    }
}
