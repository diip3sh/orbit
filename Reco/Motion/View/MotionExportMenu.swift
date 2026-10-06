//
//  MotionExportMenu.swift
//  Reco
//

import SwiftUI

/// Export in a format, then the export's progress with Cancel while it runs.
struct MotionExportMenu: View {
    let viewModel: MotionEditorViewModel

    @State private var export: Task<Void, Never>?

    var body: some View {
        if let progress = viewModel.exportProgress {
            HStack(spacing: EditorTheme.smallSpacing) {
                ProgressView(value: progress)
                    .frame(width: 120)
                Button("Cancel Export", systemImage: "xmark.circle.fill") {
                    export?.cancel()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        } else {
            Menu("Export", systemImage: "square.and.arrow.up") {
                ForEach([ExportFormat.hevc, .proRes4444, .gif]) { format in
                    Button(format.rawValue) {
                        export = Task {
                            await viewModel.export(format)
                        }
                    }
                }
            }
            .labelStyle(.titleAndIcon)
            .help("Export the video next to its bundle")
        }
    }
}
