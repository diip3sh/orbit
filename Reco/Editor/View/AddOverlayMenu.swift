//
//  AddOverlayMenu.swift
//  Reco
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The timeline toolbar's menu of overlays to add at the playhead. It stays enabled when none fits, so choosing one can
/// say why.
struct AddOverlayMenu: View {
    let viewModel: EditorViewModel
    let diameter: CGFloat

    var body: some View {
        Menu {
            Button("Text", systemImage: "textformat", action: viewModel.addTextOverlay)
                .keyboardShortcut("t", modifiers: [])
            Button("Arrow", systemImage: "arrow.up.right", action: viewModel.addArrowOverlay)
            Button("Image…", systemImage: "photo", action: chooseImage)
        } label: {
            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.theme(.title3))
                .foregroundStyle(EditorTheme.ink)
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Add Overlay")
        .help("Add an overlay at the playhead: text (T), an arrow or a picture")
    }

    private func chooseImage() {
        guard viewModel.canAddOverlay() else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose a Picture"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await viewModel.addImageOverlay(from: url) }
        }
    }
}
