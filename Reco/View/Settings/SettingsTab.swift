//
//  SettingsTab.swift
//  Reco
//

import SwiftUI

/// A pane of the Settings window, listed in its sidebar. The raw value is what the window's selected-tab default
/// stores (``AgentsSettingsView/tabStorageKey``).
enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case video
    case screenshots
    case audio
    case shortcuts
    case agents

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .video: "Video"
        case .screenshots: "Screenshots"
        case .audio: "Audio"
        case .shortcuts: "Shortcuts"
        case .agents: "Agents"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .video: "video"
        case .screenshots: "camera.viewfinder"
        case .audio: "waveform"
        case .shortcuts: "keyboard"
        case .agents: "apple.terminal"
        }
    }
}
