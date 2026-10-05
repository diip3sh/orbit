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
            Button("Settings…", action: Self.openSettings)
        } label: {
            Label { Text("More Options") } icon: { ToolbarIcon(.toolbarSettings) }
                .labelStyle(.iconOnly)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.captureToolbar)
        .fixedSize()
        .captureToolbarTooltip("Settings", shortcut: CaptureToolbarShortcut.settings.symbol)
        // A menu can't carry a key equivalent of its own, so ⌘, is a button behind it
        .background {
            Button("Settings…", action: Self.openSettings)
                .keyboardShortcut(CaptureToolbarShortcut.settings.key, modifiers: CaptureToolbarShortcut.settings.modifiers)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private static func openSettings() {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
