//
//  CaptureFilterStyle.swift
//  Reco
//
//  Created by Joshua Sattler on 30.08.26.
//

import Foundation
import ScreenCaptureKit

/// What a content filter actually captures.
///
/// `SCContentFilter.style` cannot answer this: the content sharing picker builds an
/// application selection as `SCContentFilter(display:including:exceptingWindows:)`, which
/// reports `.display` just like a full-screen selection does. The included applications are
/// the only thing that tells the two apart — a display filter has none.
enum CaptureFilterStyle: Equatable {

    /// An entire display, optionally with individual windows excluded.
    case display

    /// Every window of one or more applications, drawn on a display-sized canvas.
    case application

    /// A single desktop-independent window.
    case window

    /// A filter shape this app does not handle.
    case unknown

    /// Classifies a content filter by what it captures rather than by its reported style.
    init(_ filter: SCContentFilter) {
        if filter.style == .window {
            self = .window
        } else if !filter.includedApplications.isEmpty {
            self = .application
        } else if filter.includedDisplays.isEmpty {
            self = .unknown
        } else {
            self = .display
        }
    }
}
