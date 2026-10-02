//
//  ExportSheet.swift
//  Reco
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
        let shorterSide = min(canvasSize.width, canvasSize.height)
        let frameRate = viewModel.source?.frameRate ?? 0
        let isHDR = viewModel.source.map { $0.dynamicRange != .sdr } ?? false

        VStack(alignment: .leading, spacing: EditorTheme.spacing) {
            VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                Text("Export")
                    .font(.title2.weight(.semibold))
                Text("Saved next to the recording as \(Text(settings.format.outputURL(for: viewModel.videoURL).lastPathComponent).monospaced())")
                    .font(.callout)
                    .foregroundStyle(EditorTheme.dim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.opacity)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: EditorTheme.mediumSpacing, verticalSpacing: EditorTheme.mediumSpacing) {
                GridRow {
                    Text("Format")
                        .foregroundStyle(EditorTheme.dim)
                        .gridColumnAlignment(.trailing)
                    VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                        Picker("Format", selection: $settings.format) {
                            ForEach(ExportFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .labelsHidden()
                        Text(Self.summary(of: settings.format, isHDR: isHDR))
                            .font(.caption)
                            .foregroundStyle(EditorTheme.dim)
                            .contentTransition(.opacity)
                    }
                }
                GridRow {
                    Text("Size")
                        .foregroundStyle(EditorTheme.dim)
                    Picker("Size", selection: $settings.resolution) {
                        let resolutions = ExportSettings.resolutions(below: shorterSide, for: settings.format)
                        // A GIF is offered at the canvas's size only when it's small
                        if settings.format != .gif || !resolutions.contains(540) {
                            Text("Original, \(Self.dimensions(of: canvasSize))").tag(Int?.none)
                        }
                        ForEach(resolutions, id: \.self) { resolution in
                            Text("\(resolution, format: .number.grouping(.never))p, \(Self.dimensions(of: viewModel.exportSize(resolution: resolution)))")
                                .tag(Int?.some(resolution))
                        }
                    }
                    .labelsHidden()
                }
                GridRow {
                    Text("Frame Rate")
                        .foregroundStyle(EditorTheme.dim)
                    Picker("Frame Rate", selection: $settings.frameRate) {
                        if settings.format != .gif {
                            Text("Original, \(frameRate, format: .number.precision(.fractionLength(0...2))) fps").tag(Int?.none)
                        }
                        ForEach(ExportSettings.frameRates(below: frameRate, for: settings.format), id: \.self) { rate in
                            Text("\(rate) fps").tag(Int?.some(rate))
                        }
                    }
                    .labelsHidden()
                }
            }
            .disabled(isExporting)

            if viewModel.canvas.background == .transparent, !settings.format.keepsTransparency {
                Label("The transparent background exports black. ProRes 4444 keeps it.", systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(EditorTheme.dim)
                    .transition(.opacity)
            }

            if let progress = viewModel.exportProgress {
                ExportProgressBar(progress: progress)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let error {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.editorGhost)
                Button("Export") {
                    error = nil
                    isExporting = true
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.editorPrimary)
                .disabled(isExporting)
            }
        }
        .padding(EditorTheme.largeSpacing)
        .frame(width: 440)
        .foregroundStyle(EditorTheme.ink)
        .editorMotion(value: settings)
        .editorMotion(value: viewModel.exportProgress != nil)
        .editorMotion(value: error?.localizedDescription)
        .onChange(of: settings.format) {
            settings = settings.conformed(shorterSide: shorterSide, frameRate: frameRate)
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

    /// What the format is for, and whether an HDR recording stays HDR.
    private static func summary(of format: ExportFormat, isHDR: Bool) -> LocalizedStringKey {
        switch format {
        case .hevc: isHDR ? "Small files at high quality, in HDR." : "Small files at high quality."
        case .h264: isHDR ? "Larger files that play everywhere, in SDR." : "Larger files that play everywhere."
        case .proRes422: isHDR ? "Very large files for editing apps, in HDR." : "Very large files for editing apps."
        case .gif: "A silent loop for READMEs, pull requests and chats. Large for its size; gradients band."
        case .proRes4444:
            isHDR ? "Very large files for editing apps, in HDR with transparency." : "Very large files for editing apps, with transparency."
        }
    }

    /// "3840 × 2160"
    private static func dimensions(of size: CGSize) -> String {
        "\(Int(size.width)) × \(Int(size.height))"
    }
}
