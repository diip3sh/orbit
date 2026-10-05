//
//  CaptureToolbarMode.swift
//  Reco
//

import Foundation

/// What the capture toolbar's action does: a screenshot or a recording, of a screen, a window or an area.
/// The order is the toolbar's, as in the system's Screenshot toolbar.
nonisolated enum CaptureToolbarMode: String, CaseIterable, Identifiable, Sendable {
    case captureScreen
    case captureWindow
    case captureArea
    case recordScreen
    case recordWindow
    case recordArea

    /// What each toolbar opens on, every time: the area, the most common capture
    static func initial(records: Bool) -> Self {
        records ? .recordArea : .captureArea
    }

    var id: Self { self }

    var records: Bool {
        switch self {
        case .captureScreen, .captureWindow, .captureArea: false
        case .recordScreen, .recordWindow, .recordArea: true
        }
    }

    var title: String {
        switch self {
        case .captureScreen: "Capture Entire Screen"
        case .captureWindow: "Capture Selected Window"
        case .captureArea: "Capture Selected Portion"
        case .recordScreen: "Record Entire Screen"
        case .recordWindow: "Record Selected Window"
        case .recordArea: "Record Selected Portion"
        }
    }

    /// The tooltip's name for it: two words at most, the toolbar already says capture or record
    var shortTitle: String {
        switch self {
        case .captureScreen, .recordScreen: "Entire Screen"
        case .captureWindow, .recordWindow: "Window"
        case .captureArea, .recordArea: "Selected Area"
        }
    }

    /// The picture of what is captured; recording modes add a record badge to it
    var symbol: String {
        switch self {
        case .captureScreen, .recordScreen: "rectangle.inset.filled"
        case .captureWindow, .recordWindow: "macwindow"
        case .captureArea, .recordArea: "rectangle.dashed"
        }
    }

    var actionTitle: String {
        records ? "Record" : "Capture"
    }

    /// The recording mode that matches a selection made elsewhere (a shortcut, the Library), so the
    /// toolbar shows what Record will start.
    static func recording(isArea: Bool, isDisplay: Bool) -> Self {
        if isArea { return .recordArea }
        return isDisplay ? .recordScreen : .recordWindow
    }
}
