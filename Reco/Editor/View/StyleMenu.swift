//
//  StyleMenu.swift
//  Reco
//

import SwiftUI
import UniformTypeIdentifiers

/// The toolbar's Style menu (spec 0004, S19): the saved styles, the one the project looks like ticked, and saving,
/// importing, sharing and deleting them. A style is a `.recostyle` file, so sharing is the file itself.
struct StyleMenu: View {
    let viewModel: EditorViewModel

    @State private var isNamingStyle = false
    @State private var styleName = ""
    @State private var isImporting = false

    var body: some View {
        Menu {
            content
        } label: {
            Label("Style", systemImage: "paintpalette")
        }
        .help("Save this look as a style, or apply a saved one")
        .alert("Save Style", isPresented: $isNamingStyle) {
            TextField("Name", text: $styleName)
            Button("Save") {
                viewModel.saveStyle(named: styleName)
            }
            .disabled(styleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The canvas, cursor, clicks, keystrokes and motion settings, to apply to other recordings.")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.recoStyle, .json]) { result in
            if case .success(let url) = result {
                viewModel.importStyle(from: url)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let current = viewModel.currentStyle
        if viewModel.stylePresets.isEmpty {
            Text("No Saved Styles")
        } else {
            ForEach(viewModel.stylePresets) { preset in
                Toggle(preset.name, isOn: Binding(
                    get: { preset == current },
                    set: { isOn in
                        if isOn {
                            viewModel.apply(preset)
                        }
                    }
                ))
            }
        }
        Divider()
        Button("Save Current Style…") {
            styleName = current?.name ?? ""
            isNamingStyle = true
        }
        Button("Import Style…") {
            isImporting = true
        }
        if let current {
            ShareLink(item: viewModel.styleFile(for: current)) {
                Text("Share “\(current.name)”…")
            }
        } else {
            Button("Share Style…") {}
                .disabled(true)
        }
        if !viewModel.stylePresets.isEmpty {
            Divider()
            Menu("Delete Style") {
                ForEach(viewModel.stylePresets) { preset in
                    Button(preset.name, role: .destructive) {
                        viewModel.deleteStyle(preset)
                    }
                }
            }
        }
    }
}
