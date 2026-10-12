//
//  KeystrokesInspectorSection.swift
//  Reco
//

import SwiftUI

/// Which keystrokes are shown.
struct KeystrokesInspectorSection: View {
    @Bindable var viewModel: EditorViewModel

    var body: some View {
        let telemetry = viewModel.source?.telemetry

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Keystrokes")
            InspectorCard {
                VStack(spacing: 0) {
                    Toggle("Show Keystrokes", isOn: $viewModel.keystrokes.isEnabled)
                        .inspectorCardRow()
                    InspectorHairline()
                    Toggle("Show All Keys", isOn: $viewModel.keystrokes.showsAllKeys)
                        .inspectorCardRow()
                }
                // Text in ink doesn't dim by itself when disabled
                .opacity(telemetry?.keystrokesAvailable == true ? 1 : 0.4)
            }
            if telemetry?.keystrokesAvailable == false {
                InspectorNote("Keystrokes weren't recorded: Orbit didn't have Input Monitoring access.")
            } else if viewModel.keystrokes.showsAllKeys {
                InspectorNote("Everything typed is shown, passwords included.")
            } else {
                InspectorNote("Only shortcuts and special keys, like ⏎ and arrows, are shown.")
            }
        }
        .disabled(telemetry?.keystrokesAvailable != true)
    }
}
