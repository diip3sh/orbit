//
//  TimelineMarkers.swift
//  BetterCapture
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// When the user clicked and typed, as output times for the timeline's telemetry lanes.
nonisolated struct TimelineMarkers: Equatable, Sendable {

    /// Mouse button presses, sorted.
    var clicks: [Double]

    /// Key presses without auto-repeats, sorted.
    var keys: [Double]

    /// Events inside a cut are left out.
    init(telemetry: InputTelemetry, timeMap: TimeMap) {
        clicks = telemetry.clicks.filter(\.isDown).compactMap { timeMap.outputTime(atSource: $0.time) }
        keys = telemetry.keys.filter { !$0.isRepeat }.compactMap { timeMap.outputTime(atSource: $0.time) }
    }
}
