//
//  TimelineRuler.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Time marks above the timeline: a labelled tick every few seconds and dots between, across the
/// viewport's visible window. The tracks' grid lines fall on the same labelled times (`majors(in:width:)`).
struct TimelineRuler: View {

    /// Which part of the recording is on screen.
    let viewport: TimelineViewport

    /// The least space between labels, in points, so they never touch.
    static let labelSpacing: CGFloat = 72

    /// Labelled ticks every `major` seconds and small ones every `minor`, from 0.5 s to an hour.
    static let scales: [(major: Double, minor: Double)] = [
        (0.5, 0.1), (1, 0.25), (2, 0.5), (5, 1), (10, 2), (15, 5), (30, 5), (60, 10), (120, 30),
        (300, 60), (600, 120), (900, 300), (1800, 300), (3600, 600)
    ]

    var body: some View {
        Canvas { context, size in
            let visible = viewport.visible
            guard visible > 0, size.width > 0 else { return }
            let scale = Self.scale(duration: visible, width: size.width)
            let pointsPerSecond = size.width / visible

            // A short line at each label, a dot between
            var ticks = Path()
            let minorPerMajor = Int((scale.major / scale.minor).rounded())
            let dot: CGFloat = 2
            let firstMinor = Int((viewport.start / scale.minor).rounded(.up))
            let lastMinor = Int(viewport.end / scale.minor)
            guard firstMinor <= lastMinor else { return }
            for index in firstMinor...lastMinor {
                let tickX = (Double(index) * scale.minor - viewport.start) * pointsPerSecond
                if index.isMultiple(of: minorPerMajor) {
                    let height = size.height * 0.45
                    ticks.addRoundedRect(in: CGRect(x: tickX, y: size.height - height, width: 1, height: height), cornerSize: CGSize(width: 0.5, height: 0.5))
                } else {
                    ticks.addEllipse(in: CGRect(x: tickX - dot / 2, y: size.height - dot - CGFloat(1), width: dot, height: dot))
                }
            }
            context.fill(ticks, with: .color(EditorTheme.faint))

            for time in Self.majors(in: viewport, width: size.width) {
                let label = context.resolve(
                    Text(Self.label(for: time, major: scale.major))
                        .font(.theme(.caption2).monospacedDigit())
                        .foregroundStyle(EditorTheme.dim)
                )
                let origin = CGPoint(x: (time - viewport.start) * pointsPerSecond + 4, y: 0)
                // The last label only when it fits
                guard origin.x + label.measure(in: size).width <= size.width else { continue }
                context.draw(label, at: origin, anchor: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }

    /// The labelled times on screen, where the tracks' grid lines fall.
    static func majors(in viewport: TimelineViewport, width: CGFloat) -> [Double] {
        let scale = scale(duration: viewport.visible, width: width)
        guard scale.major > 0 else { return [] }
        let first = Int((viewport.start / scale.major).rounded(.up))
        let last = Int(viewport.end / scale.major)
        guard first <= last else { return [] }
        return (first...last).map { Double($0) * scale.major }
    }

    /// The finest scale whose labels are at least ``labelSpacing`` apart on a `width`-point ruler.
    static func scale(duration: Double, width: CGFloat) -> (major: Double, minor: Double) {
        guard duration > 0, width > 0 else { return scales[0] }
        let pointsPerSecond = width / duration
        return scales.first { $0.major * pointsPerSecond >= labelSpacing } ?? scales[scales.count - 1]
    }

    /// With its units, so a mark reads as a time on its own: "0.5s", "5s", "1m 30s", "1h". A clock's
    /// "0:00.5" needed knowing it was minutes, seconds and tenths.
    static func label(for time: Double, major: Double) -> String {
        if time < 60 {
            let seconds = Measurement(value: time, unit: UnitDuration.seconds)
            return seconds.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0...(major < 1 ? 1 : 0)))))
        }
        return Duration.seconds(time).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
    }
}
