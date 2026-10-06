//
//  ExportOptions.swift
//  Reco
//
//  Created by Diip3sh on 06.10.26.
//

import SwiftUI

/// The export page's right column: format, size and frame rate above, and below a line the action:
/// Export, then progress with Cancel, then Share and Show in Finder.
struct ExportOptions: View {
    let viewModel: EditorViewModel
    @Binding var settings: ExportSettings
    let isExporting: Bool
    let exported: URL?
    let error: (any Error)?
    let export: () -> Void
    let cancel: () -> Void

    @Namespace private var highlight

    var body: some View {
        let canvasSize = viewModel.exportSize(resolution: nil)
        let frameRate = viewModel.source?.frameRate ?? 0
        let isHDR = viewModel.source.map { $0.dynamicRange != .sdr } ?? false

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: EditorTheme.largeSpacing) {
                    section("Format") {
                        VStack(spacing: 2) {
                            ForEach(ExportFormat.allCases) { format in
                                FormatRow(format: format, isHDR: isHDR, isSelected: settings.format == format, highlight: highlight) {
                                    settings.format = format
                                }
                            }
                        }
                    }

                    section("Size") {
                        Picker("Size", selection: $settings.resolution) {
                            Text("Original").tag(Int?.none)
                            ForEach(ExportSettings.resolutions(below: min(canvasSize.width, canvasSize.height)), id: \.self) { resolution in
                                Text("\(resolution, format: .number.grouping(.never))p").tag(Int?.some(resolution))
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    section("Frame Rate") {
                        Picker("Frame Rate", selection: $settings.frameRate) {
                            Text("Original").tag(Int?.none)
                            ForEach(ExportSettings.frameRates(below: frameRate), id: \.self) { rate in
                                Text("\(rate)").tag(Int?.some(rate))
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    if viewModel.canvas.background == .transparent, !settings.format.keepsTransparency {
                        Label("The transparent background exports black. ProRes 4444 keeps it.", systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(EditorTheme.dim)
                            .transition(.opacity)
                    }
                }
                .padding(EditorTheme.largeSpacing)
                // Text in ink doesn't dim by itself when disabled
                .opacity(isExporting ? 0.4 : 1)
                .disabled(isExporting)
            }

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)

            actions
                .padding(EditorTheme.largeSpacing)
        }
        .frame(width: 320)
        .editorMotion(value: settings)
        .editorMotion(value: error?.localizedDescription)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            Text(title)
                .font(.callout)
                .foregroundStyle(EditorTheme.dim)
            content()
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
            if let progress = viewModel.exportProgress {
                ExportProgressBar(progress: progress)
                    .transition(.opacity)
            } else if let exported {
                Label("Exported \(Text(exported.lastPathComponent).monospaced())", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .transition(.opacity)
            } else {
                if let error {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.callout)
                        .transition(.opacity)
                }
                Text("Saved next to the recording as \(Text(settings.format.outputURL(for: viewModel.videoURL).lastPathComponent).monospaced())")
                    .font(.caption)
                    .foregroundStyle(EditorTheme.dim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.opacity)
            }

            if isExporting {
                Button(action: cancel) {
                    Label("Cancel", image: "button-close").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.editorSecondary)
            } else if let exported {
                // Once the file exists, sharing it is what comes next
                HStack(spacing: EditorTheme.smallSpacing) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([exported])
                    } label: {
                        Label("Finder", image: "button-folder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.editorSecondary)
                    .help("Show in Finder")
                    ShareLink(item: exported) {
                        Label("Share…", image: "button-share").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.editorPrimary)
                }
            } else {
                Button(action: export) {
                    Label("Export", image: "button-export").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.editorPrimary)
            }
        }
    }
}

/// One format: its name over what it is for, a lighter fill sliding to the one chosen.
private struct FormatRow: View {
    let format: ExportFormat
    let isHDR: Bool
    let isSelected: Bool
    let highlight: Namespace.ID
    let choose: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)

        Button(action: choose) {
            VStack(alignment: .leading, spacing: 2) {
                Text(format.rawValue)
                    .font(.body.weight(.medium))
                Text(Self.summary(of: format, isHDR: isHDR))
                    .font(.caption)
                    .foregroundStyle(EditorTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, EditorTheme.mediumSpacing)
            .padding(.vertical, EditorTheme.smallSpacing)
            .background {
                if isSelected {
                    shape
                        .fill(.primary.opacity(0.1))
                        .matchedGeometryEffect(id: "highlight", in: highlight)
                } else {
                    shape.fill(.primary.opacity(isHovered ? 0.05 : 0))
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .editorMotion(EditorTheme.quickMotion, value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// What the format is for, and whether an HDR recording stays HDR.
    private static func summary(of format: ExportFormat, isHDR: Bool) -> LocalizedStringKey {
        switch format {
        case .hevc: isHDR ? "Small files at high quality, in HDR." : "Small files at high quality."
        case .h264: isHDR ? "Larger files that play everywhere, in SDR." : "Larger files that play everywhere."
        case .proRes422: isHDR ? "Very large files for editing apps, in HDR." : "Very large files for editing apps."
        case .proRes4444:
            isHDR ? "Very large files for editing apps, in HDR with transparency." : "Very large files for editing apps, with transparency."
        }
    }
}
