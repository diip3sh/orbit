//
//  CaptureToolbarMoreMenu.swift
//  Reco
//

import SwiftUI

/// Less used settings behind a gear: the cursor, and Settings.
struct CaptureToolbarMoreMenu: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Menu {
            Toggle("Show Cursor", isOn: $settings.showCursor)
                // The editor draws the cursor instead
                .disabled(settings.leavesCursorToEditor)
            Divider()
            Button("Settings…") {
                NSApp.activate()
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        } label: {
            Label { Text("More Options") } icon: { ToolbarIcon(.toolbarSettings) }
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.captureToolbar)
        .fixedSize()
        .captureToolbarTooltip("More Options")
    }
}
