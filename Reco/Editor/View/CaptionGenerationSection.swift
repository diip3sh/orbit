//
//  CaptionGenerationSection.swift
//  Reco
//

import SwiftUI

/// The language and Generate, or progress with Cancel while it runs.
@available(macOS 26, *)
struct CaptionGenerationSection: View {
    @Bindable var viewModel: EditorViewModel

    @State private var confirmsReplacing = false

    var body: some View {
        let hasCues = !viewModel.captions.cues.isEmpty

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Transcript")
            InspectorCard {
                HStack {
                    Text("Language")
                    Spacer()
                    Picker("Language", selection: $viewModel.captionGeneration.language) {
                        ForEach(viewModel.captionGeneration.languages, id: \.self) { language in
                            Text(Transcriber.name(ofLanguage: language)).tag(Optional(language))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .inspectorCardRow()
                .disabled(viewModel.captionGeneration.progress != nil)
            }
            if let progress = viewModel.captionGeneration.progress {
                InspectorCard {
                    VStack(alignment: .leading, spacing: EditorTheme.tightSpacing) {
                        Text(progress.title)
                            .foregroundStyle(EditorTheme.dim)
                        HStack {
                            // A model's download can report nothing until it's done
                            if progress.fraction > 0 {
                                ProgressView(value: progress.fraction)
                            } else {
                                ProgressView()
                                    .progressViewStyle(.linear)
                            }
                            Button("Cancel", action: viewModel.cancelGeneratingCaptions)
                                .buttonStyle(.borderless)
                        }
                    }
                    .inspectorCardRow()
                }
            } else {
                Button {
                    if viewModel.captions.hasEditedCues {
                        confirmsReplacing = true
                    } else {
                        viewModel.generateCaptions()
                    }
                } label: {
                    Label(hasCues ? "Regenerate Captions" : "Generate Captions", systemImage: "captions.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.editorSecondary)
                .disabled(viewModel.source == nil || viewModel.captionGeneration.language == nil)
            }
            if let notice = viewModel.captionGeneration.notice {
                InspectorNote(LocalizedStringKey(notice))
            } else if !hasCues {
                InspectorNote("Transcribed on this Mac. Nothing leaves it.")
            }
        }
        .editorMotion(value: viewModel.captionGeneration.progress == nil)
        .confirmationDialog("Replace your edited captions?", isPresented: $confirmsReplacing) {
            Button("Replace", role: .destructive, action: viewModel.generateCaptions)
        } message: {
            Text("Generating again discards the changes you made to them. You can undo it.")
        }
    }
}
