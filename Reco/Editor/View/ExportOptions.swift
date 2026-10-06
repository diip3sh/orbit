//
//  ExportOptions.swift
//  Reco
//
//  Created by Diip3sh on 06.10.26.
//

import SwiftUI

/// The export page's inspector, in the editor inspector's sections and controls: format, size and frame rate,
/// and pinned under a line the action: Export, then progress with Cancel, then Share and Show in Finder.
struct ExportOptions: View {
    let viewModel: EditorViewModel
    @Bindable var session: ExportSession
    /// Whether the title bar's name is being edited, which Esc must end before it leaves export.
    let isRenaming: Bool
    let back: () -> Void

    @Namespace private var highlight

    var body: some View {
        let canvasSize = viewModel.exportSize(resolution: nil)
        let frameRate = viewModel.source?.frameRate ?? 0
        let isHDR = viewModel.source.map { $0.dynamicRange != .sdr } ?? false
        let resolutions = ExportSettings.resolutions(below: min(canvasSize.width, canvasSize.height))
        let frameRates = ExportSettings.frameRates(below: frameRate)

        VStack(spacing: 0) {
            navigation
                .frame(maxWidth: .infinity, alignment: .leading)
                // The column's content already starts under the toolbar's strip
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 0) {
                    InspectorSection("Format") {
                        VStack(spacing: 2) {
                            ForEach(ExportFormat.allCases) { format in
                                FormatRow(format: format, isHDR: isHDR, isSelected: session.settings.format == format, highlight: highlight) {
                                    session.settings.format = format
                                }
                            }
                        }
                    } footer: {
                        if viewModel.canvas.background == .transparent, !session.settings.format.keepsTransparency {
                            Text("The transparent background exports black. ProRes 4444 keeps it.")
                        }
                    }

                    InspectorSection("Size") {
                        SegmentedChoice(
                            selection: $session.settings.resolution,
                            options: [(nil, "Original")] + resolutions.map { (Optional($0), "\($0)p") }
                        )
                    }

                    InspectorSection("Frame Rate") {
                        SegmentedChoice(
                            selection: $session.settings.frameRate,
                            options: [(nil, "Original")] + frameRates.map { (Optional($0), "\($0) fps") }
                        )
                    }

                    InspectorSection("File") {
                        ForEach(facts) { fact in
                            HStack {
                                Text(fact.title)
                                    .foregroundStyle(EditorTheme.dim)
                                Spacer()
                                Text(fact.value)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .contentTransition(.numericText())
                            }
                            .transition(.opacity)
                        }
                    }
                }
                .controlSize(.small)
                // Text in ink doesn't dim by itself when disabled
                .opacity(session.isExporting ? 0.4 : 1)
                .disabled(session.isExporting)
            }
            .scrollIndicators(.never)

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(height: 1)

            actions
                .padding()
        }
        .editorMotion(value: session.settings)
        .editorMotion(value: session.exported)
        .editorMotion(value: session.isExporting)
        .editorMotion(value: session.error?.localizedDescription)
        // Closing the window mid-export ends it too
        .onDisappear(perform: session.cancel)
    }

    /// What the file will be, and once it exists, how big it is. No estimate of the size before: it depends on
    /// what is on screen, and a wrong number is worse than none.
    private var facts: [ExportFact] {
        let settings = session.settings
        let size = viewModel.exportSize(resolution: settings.resolution)
        let frameRate = settings.frameRate.map(Double.init) ?? viewModel.source?.frameRate ?? 0
        var facts = [
            ExportFact(title: "Duration", value: Duration.seconds(viewModel.timeMap.outputDuration)
                .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1)))),
            ExportFact(title: "Size", value: "\(Int(size.width)) × \(Int(size.height))"),
            ExportFact(title: "Frame Rate", value: "\(frameRate.formatted(.number.precision(.fractionLength(0...2)))) fps"),
            ExportFact(title: "Container", value: settings.format.fileExtension.uppercased())
        ]
        if let exportedBytes = session.exportedBytes {
            facts.append(ExportFact(title: "File Size", value: Int64(exportedBytes).formatted(.byteCount(style: .file))))
        }
        return facts
    }

    /// Back to the editor; forward has nowhere to go from export, so it is there only to read as the pair.
    /// A glass capsule like the toolbar's: `ControlGroup`'s navigation style is a capsule only in a toolbar, and a
    /// bordered box anywhere else.
    private var navigation: some View {
        HStack(spacing: 0) {
            Button("Editor", systemImage: "chevron.left", action: back)
                // Esc ends a rename first
                .keyboardShortcut(isRenaming ? nil : .cancelAction)
                .disabled(session.isExporting)
                .help("Back to the editor (Esc)")
            Divider()
                .frame(height: 16)
            Button("Export", systemImage: "chevron.right") {}
                .disabled(true)
        }
        .buttonStyle(.editorIcon)
        .fontWeight(.semibold)
        .padding(3)
        .editorGlass(in: .capsule)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
            if let progress = viewModel.exportProgress {
                ExportProgressBar(progress: progress)
                    .transition(.opacity)
            } else if let exported = session.exported {
                Label("Exported \(Text(exported.lastPathComponent).monospaced())", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .transition(.opacity)
            } else {
                if let error = session.error {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.callout)
                        .transition(.opacity)
                }
                Text("Saved next to the recording as \(Text(session.settings.format.outputURL(for: viewModel.videoURL).lastPathComponent).monospaced())")
                    .font(.caption)
                    .foregroundStyle(EditorTheme.dim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .contentTransition(.opacity)
            }

            if session.isExporting {
                Button(action: session.cancel) {
                    Label("Cancel", image: "button-close").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.editorSecondary)
            } else if let exported = session.exported {
                // Once the file exists, sharing it is what comes next
                HStack(spacing: EditorTheme.smallSpacing) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([exported])
                    } label: {
                        Label("Show in Finder", image: "button-folder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.editorSecondary)
                    ShareLink(item: exported) {
                        Label("Share…", image: "button-share").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.editorPrimary)
                }
            } else {
                Button(action: session.start) {
                    Label("Export", image: "button-export").frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.editorPrimary)
            }
        }
    }
}

private struct ExportFact: Identifiable {
    let title: LocalizedStringKey
    let value: String

    var id: String { "\(title)" }
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
                    .font(.callout.weight(.medium))
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
