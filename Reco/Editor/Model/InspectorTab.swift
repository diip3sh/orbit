//
//  InspectorTab.swift
//  Reco
//
//  Created by Diip3sh on 07.10.26.
//

import Foundation

/// The editor inspector's tabs, in the bar's order. Each shows only its own sections.
nonisolated enum InspectorTab: CaseIterable, Hashable, Sendable {
    case background, camera, audio, cursor, keyboard, caption, motion

    var title: String {
        switch self {
        case .background: "Background"
        case .camera: "Camera"
        case .audio: "Audio"
        case .cursor: "Cursor"
        case .keyboard: "Keyboard"
        case .caption: "Captions"
        case .motion: "Motion"
        }
    }

    var symbol: String {
        switch self {
        case .background: "photo"
        case .camera: "web.camera"
        case .audio: "speaker.wave.2"
        case .cursor: "cursorarrow"
        case .keyboard: "command"
        case .caption: "captions.bubble"
        case .motion: "point.topleft.down.to.point.bottomright.curvepath"
        }
    }

    /// Tabs in one group sit together; the bar draws a line between groups.
    var group: Int {
        switch self {
        case .background, .camera: 0
        case .audio: 1
        case .cursor, .keyboard: 2
        case .caption: 3
        case .motion: 4
        }
    }

    /// Whether the tab has anything to edit. Camera needs the camera as its own track and captions a
    /// transcript; neither is recorded yet (spec 0004, N19 and N5). Audio is always there: a silent
    /// recording can still get music.
    var isAvailable: Bool {
        switch self {
        case .camera, .caption: false
        case .background, .audio, .cursor, .keyboard, .motion: true
        }
    }

    /// Why ``isAvailable`` is false, for the tab's tooltip.
    var unavailableReason: String {
        switch self {
        case .camera: "Camera: recorded into the video, so it can't be edited"
        case .caption: "Captions: coming soon"
        case .background, .audio, .cursor, .keyboard, .motion: title
        }
    }
}
