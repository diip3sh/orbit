//
//  EditorInspector.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import SwiftUI

/// Style controls for the overlays drawn from input telemetry: click highlights and keystrokes.
struct EditorInspector: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry

        Form {
            Section {
                Toggle("Highlight Clicks", isOn: $viewModel.clickHighlights.isEnabled)
                ColorPicker("Color", selection: $viewModel.clickHighlights.color.cgColor)
                LabeledContent("Size") {
                    Slider(value: $viewModel.clickHighlights.size, in: 16...120)
                }
                LabeledContent("Duration") {
                    Slider(value: $viewModel.clickHighlights.duration, in: 0.2...1.5)
                }
                Picker("Buttons", selection: $viewModel.clickHighlights.buttons) {
                    Text("All").tag(ClickHighlightStyle.Buttons.all)
                    Text("Left Only").tag(ClickHighlightStyle.Buttons.left)
                    Text("Right Only").tag(ClickHighlightStyle.Buttons.right)
                }
            } header: {
                Text("Clicks")
            } footer: {
                if let reason = viewModel.source?.telemetryError {
                    Text(reason.localizedDescription)
                }
            }
            .disabled(telemetry == nil)

            Section {
                Toggle("Show Keystrokes", isOn: $viewModel.keystrokes.isEnabled)
                Toggle("Show All Keys", isOn: $viewModel.keystrokes.showsAllKeys)
            } header: {
                Text("Keystrokes")
            } footer: {
                if telemetry?.keystrokesAvailable == false {
                    Text("Keystrokes weren't recorded: BetterCapture didn't have Input Monitoring access.")
                } else if viewModel.keystrokes.showsAllKeys {
                    Text("Everything typed is shown, passwords included.")
                } else {
                    Text("Only shortcuts and special keys, like ⏎ and arrows, are shown.")
                }
            }
            .disabled(telemetry?.keystrokesAvailable != true)
        }
        .formStyle(.grouped)
    }
}
