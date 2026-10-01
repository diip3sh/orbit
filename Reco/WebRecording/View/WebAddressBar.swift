//
//  WebAddressBar.swift
//  Reco
//

import SwiftUI

/// The page's address on glass: ⏎ loads what's typed, the button reloads the script's page.
struct WebAddressBar: View {
    @Bindable var viewModel: WebRecordingViewModel

    var body: some View {
        HStack(spacing: EditorTheme.smallSpacing) {
            Image(systemName: "globe")
                .foregroundStyle(EditorTheme.dim)
            TextField("Address", text: $viewModel.address, prompt: Text("Enter a web address"))
                .textFieldStyle(.plain)
                .onSubmit {
                    viewModel.commitAddress()
                }
            Button("Reload", systemImage: "arrow.clockwise") {
                viewModel.reload()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(EditorTheme.dim)
            .help("Load the script's page again")
            .disabled(viewModel.script.url == nil)
        }
        .padding(.horizontal, EditorTheme.mediumSpacing)
        .frame(maxWidth: 560, minHeight: 32)
        .editorGlass(in: .capsule)
    }
}
