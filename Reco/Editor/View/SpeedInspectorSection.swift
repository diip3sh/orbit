//
//  SpeedInspectorSection.swift
//  Reco
//
//  Created by Diip3sh on 08.10.26.
//

import SwiftUI

/// Speeding up the typing. A single part's speed is in the transport.
struct SpeedInspectorSection: View {
    let viewModel: EditorViewModel

    var body: some View {
        let speedUps = viewModel.typingSpeedUps

        VStack(alignment: .leading, spacing: EditorTheme.smallSpacing) {
            InspectorSectionHeader("Speed")
            InspectorCard {
                Button {
                    viewModel.speedUpTyping()
                } label: {
                    Label("Speed Up Typing", systemImage: "keyboard.badge.ellipsis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.editorSecondary)
                .disabled(speedUps.isEmpty)
                .inspectorCardRow()
            }
            if viewModel.source?.telemetry?.keystrokesAvailable == false {
                InspectorNote("No keystrokes were recorded (they need Input Monitoring), so typing can't be found.")
            } else if speedUps.isEmpty {
                InspectorNote("No typing of 3 s or more left at 1×. Select a part on the timeline to set its speed in the transport.")
            } else {
                InspectorNote("Plays ^[\(speedUps.count) stretch](inflect: true) of typing at 2–4×, each as its own part.")
            }
        }
    }
}
