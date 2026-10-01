//
//  TimelineRuler.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import SwiftUI

/// Time marks above the timeline: a labelled tick every few seconds and small ones between.
struct TimelineRuler: View {

    /// The recording's length in seconds, which spans the ruler.
    let duration: Double

    /// The least space between labels, in points, so they never touch.
    static let labelSpacing: CGFloat = 72

    /// Labelled ticks every `major` seconds and small ones every `minor`, from 0.5 s to an hour.
    static let scales: [(major: Double, minor: Double)] = [
        (0.5, 0.1), (1, 0.25), (2, 0.5), (5, 1), (10, 2), (15, 5), (30, 5), (60, 10), (120, 30),
        (300, 60), (600, 120), (900, 300), (1800, 300), (3600, 600)
    ]

    var body: some View {
        Canvas { context, size in
            guard duration > 0, size.width > 0 else { return }
            let scale = Self.scale(duration: duration, width: size.width)
            let pointsPerSecond = size.width / duration

            var ticks = Path()
            let minorPerMajor = Int((scale.major / scale.minor).rounded())
            for index in 0...Int(duration / scale.minor) {
                let height = index.isMultiple(of: minorPerMajor) ? size.height * 0.45 : size.height * 0.2
                ticks.addRect(CGRect(x: Double(index) * scale.minor * pointsPerSecond, y: size.height - height, width: 1, height: height))
            }
            context.fill(ticks, with: .color(EditorTheme.faint))

            for index in 0...Int(duration / scale.major) {
                let time = Double(index) * scale.major
                let label = context.resolve(
                    Text(Self.label(for: time, major: scale.major))
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(EditorTheme.dim)
                )
                let origin = CGPoint(x: time * pointsPerSecond + 4, y: 0)
                // The last label only when it fits
                guard origin.x + label.measure(in: size).width <= size.width else { continue }
                context.draw(label, at: origin, anchor: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }

    /// The finest scale whose labels are at least ``labelSpacing`` apart on a `width`-point ruler.
    static func scale(duration: Double, width: CGFloat) -> (major: Double, minor: Double) {
        let pointsPerSecond = width / duration
        return scales.first { $0.major * pointsPerSecond >= labelSpacing } ?? scales[scales.count - 1]
    }

    /// "0:05", "1:00:00", or "0:00.5" when labels are less than a second apart.
    static func label(for time: Double, major: Double) -> String {
        let duration = Duration.seconds(time)
        if time >= 3600 {
            return duration.formatted(.time(pattern: .hourMinuteSecond))
        }
        return duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: major < 1 ? 1 : 0)))
    }
}
