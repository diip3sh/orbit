//
//  TimelineMarkers.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// When the user clicked and typed, as source times for the timeline's telemetry lanes.
nonisolated struct TimelineMarkers: Equatable, Sendable {

    /// Mouse button presses, sorted.
    var clicks: [Double]

    /// Key presses without auto-repeats, sorted.
    var keys: [Double]

    init(telemetry: InputTelemetry) {
        clicks = telemetry.clicks.filter(\.isDown).map(\.time)
        keys = telemetry.keys.filter { !$0.isRepeat }.map(\.time)
    }
}
