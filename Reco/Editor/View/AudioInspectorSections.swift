//
//  AudioInspectorSections.swift
//  Reco
//

import SwiftUI
import UniformTypeIdentifiers

/// Each audio track's volume and mute, and Enhance Voice on the microphone's.
struct AudioInspectorSection: View {
    @Bindable var viewModel: EditorViewModel
    let trackNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Audio")
            InspectorCard {
                VStack(spacing: 0) {
                    ForEach(trackNames.indices, id: \.self) { index in
                        if index > 0 {
                            InspectorHairline()
                        }
                        AudioTrackRow(
                            name: trackNames[index],
                            mayHoldVoice: index == viewModel.source?.voiceTrackIndex,
                            settings: $viewModel.audio[track: index]
                        )
                        .inspectorCardRow()
                    }
                }
            }
            if viewModel.source?.voiceTrackIndex != nil {
                InspectorNote("Enhance Voice takes out the noise around the voice.")
            }
        }
    }
}

/// The music looped under the whole video, with its volume and mute, or a button to choose a file.
struct BackgroundAudioInspectorSection: View {
    @Bindable var viewModel: EditorViewModel
    @State private var choosesFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Background Audio")
            InspectorCard {
                Group {
                    if let background = Binding(unwrapping: $viewModel.audio.background) {
                        VStack(spacing: 0) {
                            AudioTrackRow(name: background.wrappedValue.name, settings: background.track)
                                .inspectorCardRow()
                            InspectorHairline()
                            Button {
                                viewModel.removeBackgroundAudio()
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.editorSecondary)
                            .inspectorCardRow()
                        }
                    } else {
                        Button {
                            choosesFile = true
                        } label: {
                            Label("Add Background Audio…", systemImage: "music.note")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.editorSecondary)
                        .inspectorCardRow()
                    }
                }
                .transition(.opacity)
            }
            InspectorNote("Loops under the whole video, fading in and out at the ends.")
        }
        .editorMotion(value: viewModel.audio.background != nil)
        .fileImporter(isPresented: $choosesFile, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result {
                viewModel.setBackgroundAudio(url)
            }
        }
    }
}
