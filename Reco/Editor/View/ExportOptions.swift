//
//  ExportOptions.swift
//  Reco
//
//  Created by Diip3sh on 06.10.26.
//

import SwiftUI

/// The export page's inspector, in the editor inspector's sections and controls: the format, size and frame rate
/// as tabs, the quality as rows with each one's estimated size, and pinned under a line the actions: Export and
/// Copy to Clipboard, then progress with Cancel, then Share and Show in Finder.
struct ExportOptions: View {
    let viewModel: EditorViewModel
    @Bindable var session: ExportSession

    @Namespace private var highlight

    var body: some View {
        let settings = session.settings
        let recordingRate = viewModel.source?.frameRate ?? 0
        let canvasSize = viewModel.exportSize(resolution: nil)
        let exportSize = viewModel.exportSize(resolution: settings.resolution)

        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    InspectorSection("Export As") {
                        SegmentedChoice(
                            selection: $session.settings.format,
                            options: ExportFormat.allCases.map { ($0, $0.title(transparentCanvas: settings.transparentCanvas)) }
                        )
                    } footer: {
                        if settings.transparentCanvas, !settings.keepsTransparency {
                            Text("The transparent background exports black. ProRes keeps it.")
                        }
                    }

                    InspectorSection("Output Size") {
                        SegmentedChoice(
                            selection: $session.settings.resolution,
                            options: [(nil, "Original")] + ExportSettings.resolutions.map { (Optional($0), Self.title(ofResolution: $0)) }
                        ) { resolution in
                            resolution.map { ExportSettings.isAvailable(resolution: $0, below: min(canvasSize.width, canvasSize.height)) } ?? true
                        }
                    } footer: {
                        Text("\(Int(exportSize.width)) × \(Int(exportSize.height)) px")
                            .monospacedDigit()
                    }

                    InspectorSection("Frame Rate") {
                        SegmentedChoice(
                            selection: Binding(
                                get: { settings.selectedFrameRate(recordingRate: recordingRate) },
                                set: { rate in
                                    if let rate {
                                        session.settings.choose(frameRate: rate, recordingRate: recordingRate)
                                    }
                                }
                            ),
                            options: ExportSettings.frameRates.map { (Optional($0), "\($0) fps") }
                        ) { rate in
                            rate.map { settings.isAvailable(frameRate: $0, recordingRate: recordingRate) } ?? false
                        }
                    } footer: {
                        if settings.format == .gif {
                            Text("GIF size depends on what's on screen.")
                        }
                    }

                    if settings.format != .gif {
                        InspectorSection("Quality") {
                            qualityRows
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
        .editorMotion(value: session.copied)
        .editorMotion(value: session.isExporting)
        .editorMotion(value: session.error?.localizedDescription)
        // Closing the window mid-export ends it too
        .onDisappear(perform: session.cancel)
    }

    private static func title(ofResolution resolution: Int) -> String {
        resolution == 2160 ? "4K" : "\(resolution)p"
    }

    /// The levels, or for a transparent ProRes movie its one: 4444 is the only flavour that keeps transparency.
    @ViewBuilder
    private var qualityRows: some View {
        VStack(spacing: 2) {
            if session.settings.keepsTransparency {
                QualityRow(
                    title: "ProRes 4444", summary: "One level, which keeps transparency.", bytes: session.estimatedBytes(),
                    isSelected: true, highlight: highlight
                ) {}
            } else {
                ForEach(ExportQuality.allCases) { quality in
                    QualityRow(
                        title: quality.title, summary: quality.summary, bytes: session.estimatedBytes(quality: quality),
                        isSelected: session.settings.quality == quality, highlight: highlight
                    ) {
                        session.settings.quality = quality
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: EditorTheme.mediumSpacing) {
            if let progress = viewModel.exportProgress {
                ExportProgressBar(progress: progress)
                    .transition(.opacity)
            } else if let exported = session.exported {
                VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                    Label("Exported \(Text(exported.lastPathComponent).monospaced())", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let bytes = session.exportedBytes {
                        Text(Int64(bytes).formatted(.byteCount(style: .file)))
                            .font(.caption)
                            .foregroundStyle(EditorTheme.dim)
                    }
                }
                .transition(.opacity)
            } else {
                if session.copied {
                    Label("Copied to Clipboard", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .transition(.opacity)
                }
                if let error = session.error {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.callout)
                        .transition(.opacity)
                }
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
                buttons
                if let bytes = session.estimatedBytes() {
                    Text("Estimated max size — \(Text(bytes.formatted(.byteCount(style: .file))).monospacedDigit())")
                        .font(.caption)
                        .foregroundStyle(EditorTheme.dim)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.opacity)
                }
            }
        }
    }

    /// Side by side when the column is wide enough for both, else one above the other.
    private var buttons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: EditorTheme.smallSpacing) {
                exportButton
                copyButton
            }
            VStack(spacing: EditorTheme.smallSpacing) {
                exportButton
                copyButton
            }
        }
    }

    private var exportButton: some View {
        Button(action: session.start) {
            ActionLabel(title: "Export", keys: "↩", icon: Image("button-export"))
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.editorPrimary)
        .help("Saved next to the recording as \(session.settings.format.outputURL(for: viewModel.videoURL).lastPathComponent)")
    }

    private var copyButton: some View {
        Button(action: session.copy) {
            ActionLabel(title: "Copy to Clipboard", keys: "⌘↩", icon: Image(systemName: "doc.on.doc"))
        }
        .keyboardShortcut(.return, modifiers: .command)
        .buttonStyle(.editorSecondary)
    }
}

/// A button's title with its shortcut beside it, dimmer, as the Quick Access card's. VoiceOver reads the shortcut
/// from the button.
private struct ActionLabel: View {
    let title: LocalizedStringKey
    let keys: String
    let icon: Image

    var body: some View {
        Label {
            HStack(spacing: EditorTheme.tightSpacing) {
                Text(title)
                Text(keys)
                    .opacity(0.5)
                    .accessibilityHidden(true)
            }
        } icon: {
            icon
        }
        .frame(maxWidth: .infinity)
    }
}

private extension ExportFormat {

    /// The tab's label: ProRes is 4444 when the canvas is transparent, the flavour that keeps it.
    func title(transparentCanvas: Bool) -> String {
        switch self {
        case .mp4: "MP4"
        case .proRes: transparentCanvas ? "ProRes 4444" : "ProRes 422"
        case .gif: "GIF"
        }
    }
}

private extension ExportQuality {

    var title: LocalizedStringKey {
        switch self {
        case .studio: "Studio"
        case .socialMedia: "Social Media"
        case .web: "Web"
        case .webLow: "Web (Low)"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .studio: "Highest quality, for further editing."
        case .socialMedia: "High quality at a size social sites accept."
        case .web: "Smaller files for pages and docs."
        case .webLow: "Smallest files, visibly compressed."
        }
    }
}

/// One quality level: its name over what it is for and, on the right, the size the file will have, a lighter fill
/// sliding to the one chosen.
private struct QualityRow: View {
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let bytes: Int64?
    let isSelected: Bool
    let highlight: Namespace.ID
    let choose: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8)

        Button(action: choose) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Spacer()
                    if let bytes {
                        Text("≈ \(bytes.formatted(.byteCount(style: .file)))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(EditorTheme.dim)
                            .contentTransition(.numericText())
                    }
                }
                Text(summary)
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
}
