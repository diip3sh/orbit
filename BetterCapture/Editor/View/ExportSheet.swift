//
//  ExportSheet.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// Picks a format and exports the edited video, with progress. Cancel stops a running export.
struct ExportSheet: View {
    let viewModel: EditorViewModel

    @State private var format = ExportFormat.hevc
    @State private var isExporting = false
    @State private var error: (any Error)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Picker("Format", selection: $format) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
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
                try await viewModel.export(as: format)
                dismiss()
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error
                isExporting = false
            }
        }
    }
}
