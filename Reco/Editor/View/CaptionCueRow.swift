//
//  CaptionCueRow.swift
//  Reco
//

import SwiftUI

/// A caption in the list: its time, which seeks there, its text, and Delete. The text is changed when the field
/// ends, so typing a sentence is one edit and one undo step.
struct CaptionCueRow: View {
    let viewModel: EditorViewModel
    let cue: CaptionCue
    let isSelected: Bool

    @State private var draft = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: EditorTheme.smallSpacing) {
            Button {
                viewModel.seekToCaption(cue.id)
            } label: {
                Text(Duration.seconds(cue.range.lowerBound), format: .time(pattern: .minuteSecond))
                    .font(.theme(.caption).monospacedDigit())
                    .foregroundStyle(isSelected ? EditorTheme.ink : EditorTheme.dim)
            }
            .buttonStyle(.plain)
            .help("Go to this caption")

            TextField("Caption", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .labelsHidden()
                .lineLimit(1...4)
                .focused($isEditing)
                .onSubmit(commit)

            Button("Delete Caption", systemImage: "trash") {
                viewModel.deleteCaption(cue.id)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Delete this caption")
        }
        .inspectorCardRow()
        .background(isSelected ? EditorTheme.ink.opacity(0.06) : .clear)
        .onAppear { draft = cue.text }
        // Turning to another tab or scrolling away ends the field without a word about it
        .onDisappear(perform: commit)
        // An undo, or a word fixed elsewhere
        .onChange(of: cue.text) { _, text in draft = text }
        .onChange(of: isEditing) { _, isEditing in
            if isEditing {
                viewModel.seekToCaption(cue.id)
            } else {
                commit()
            }
        }
    }

    private func commit() {
        viewModel.setCaptionText(cue.id, to: draft)
        // Blank changes nothing, so the field shows what the caption still says
        draft = viewModel.project.captions.cues.first { $0.id == cue.id }?.text ?? draft
    }
}
