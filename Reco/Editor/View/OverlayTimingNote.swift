//
//  OverlayTimingNote.swift
//  Reco
//

import SwiftUI

/// When an overlay shows in the edited video, in the transport's time.
struct OverlayTimingNote: View {
    let timeMap: TimeMap
    let overlay: VideoOverlay

    var body: some View {
        let start = timeMap.outputTime(atSource: overlay.range.lowerBound)
        let end = timeMap.outputTime(atSource: overlay.range.upperBound)
        if start < end {
            let seconds = (end - start).formatted(.number.precision(.fractionLength(2)))
            InspectorNote("Shows from \(Self.format(start)) to \(Self.format(end)), for \(seconds) s. Lane \(overlay.lane + 1) of \(VideoOverlay.laneCount).")
        } else {
            InspectorNote("It's entirely cut, so it doesn't show.")
        }
    }

    private static func format(_ seconds: Double) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 2)))
    }
}
