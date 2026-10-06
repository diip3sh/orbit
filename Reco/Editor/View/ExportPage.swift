//
//  ExportPage.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// The editor window's export page, pushed over the editor: the edited video on the stage with the facts
/// about its file under it, and the format, size and frame rate in a column on the right. Exporting shows
/// progress there, then offers to share the file or show it in Finder. Back (Esc) returns to the editor;
/// while an export runs it is Cancel that Esc presses.
struct ExportPage: View {
    let viewModel: EditorViewModel
    let close: () -> Void

    @State private var settings: ExportSettings
    @State private var isExporting = false
    @State private var exported: URL?
    @State private var exportedBytes: Int?
    @State private var error: (any Error)?

    init(viewModel: EditorViewModel, close: @escaping () -> Void) {
        self.viewModel = viewModel
        self.close = close
        // Only ProRes 4444 keeps a transparent background
        _settings = State(initialValue: ExportSettings(format: viewModel.canvas.background == .transparent ? .proRes4444 : .hevc))
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                EditorStage(viewModel: viewModel)
                ExportFacts(
                    isPlaying: viewModel.playback.isPlaying,
                    togglePlay: viewModel.playback.togglePlay,
                    facts: facts
                )
                .padding(.bottom, EditorTheme.largeSpacing)
            }
            .frame(maxWidth: .infinity)
            .background(EditorTheme.stage)

            Rectangle()
                .fill(EditorTheme.hairline)
                .frame(width: 1)

            ExportOptions(
                viewModel: viewModel,
                settings: $settings,
                isExporting: isExporting,
                exported: exported,
                error: error,
                export: startExport,
                cancel: stopExport
            )
        }
        .background(EditorTheme.stage.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("Editor", systemImage: "chevron.left") { close() }
                    .labelStyle(.titleAndIcon)
                    .keyboardShortcut(.cancelAction)
                    .disabled(isExporting)
                    .help("Back to the editor (Esc)")
            }
            ToolbarItem(placement: .principal) {
                Text("Export")
                    .font(.headline)
            }
        }
        .editorMotion(value: exported)
        .editorMotion(value: isExporting)
        // Another format, size or frame rate is another file, exported again
        .onChange(of: settings) {
            exported = nil
            exportedBytes = nil
        }
        // The page is for looking, not editing: it opens on a paused frame and leaves the editor on one
        .onAppear { viewModel.playback.pause() }
        .onDisappear { viewModel.playback.pause() }
        // Leaving the page, or Cancel, ends the task, and with it the export
        .task(id: isExporting) {
            guard isExporting else { return }
            do {
                exported = try await viewModel.export(settings)
                exportedBytes = exported.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
                isExporting = false
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error
                isExporting = false
            }
        }
    }

    private func startExport() {
        error = nil
        isExporting = true
    }

    private func stopExport() {
        isExporting = false
    }

    /// What the file will be, and once it exists, how big it is. No estimate of the size before: it depends on
    /// what is on screen, and a wrong number is worse than none.
    private var facts: [ExportFacts.Fact] {
        let size = viewModel.exportSize(resolution: settings.resolution)
        let frameRate = settings.frameRate.map(Double.init) ?? viewModel.source?.frameRate ?? 0
        var facts = [
            ExportFacts.Fact(
                title: "Duration",
                value: Duration.seconds(viewModel.timeMap.outputDuration)
                    .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1)))
            ),
            ExportFacts.Fact(
                title: "Output",
                value: "\(Int(size.width)) × \(Int(size.height)) · \(frameRate.formatted(.number.precision(.fractionLength(0...2)))) fps"
            ),
            ExportFacts.Fact(title: "Format", value: "\(settings.format.rawValue) · \(settings.format.fileExtension.uppercased())")
        ]
        if let exportedBytes {
            facts.append(ExportFacts.Fact(title: "File Size", value: Int64(exportedBytes).formatted(.byteCount(style: .file))))
        }
        return facts
    }
}

/// The play button and a row of facts, under the preview, divided by hairlines.
private struct ExportFacts: View {
    struct Fact: Identifiable {
        let title: LocalizedStringKey
        let value: String

        var id: String { value + "\(title)" }
    }

    let isPlaying: Bool
    let togglePlay: () -> Void
    let facts: [Fact]

    var body: some View {
        HStack(spacing: EditorTheme.spacing) {
            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill", action: togglePlay)
                .keyboardShortcut(.space, modifiers: [])
                .buttonStyle(.editorProminentIcon)
                .contentTransition(.symbolEffect(.replace))

            ForEach(facts) { fact in
                Rectangle()
                    .fill(EditorTheme.hairline)
                    .frame(width: 1, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.title)
                        .font(.caption)
                        .foregroundStyle(EditorTheme.dim)
                    Text(fact.value)
                        .font(.callout)
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText())
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, EditorTheme.spacing)
        .padding(.vertical, EditorTheme.smallSpacing)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(EditorTheme.hairline)
        }
        .editorMotion(value: facts.map(\.value))
    }
}
