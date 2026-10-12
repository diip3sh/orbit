//
//  TelemetryLane.swift
//  Reco
//
//  Created by Diip3sh on 10.10.26.
//

import SwiftUI

/// The timeline's clicks & keys row: a baseline over each kept part, a dot per click on it, a
/// diamond per shortcut (keys held with ⌘, ⌃ or ⌥ — plain typing is summarized instead) and a
/// "Typing · N s" pill over each stretch of typing.
struct TelemetryLane: View {
    let viewModel: EditorViewModel

    /// The timeline's width, in points.
    let width: CGFloat

    static let height: CGFloat = 20

    /// The baseline's vertical middle; clicks sit on it.
    private static let baselineY: CGFloat = 5

    var body: some View {
        Canvas { context, size in
            let viewport = viewModel.viewport
            guard viewport.visible > 0, let markers = viewModel.markers else { return }
            let xAt = { (time: Double) in viewport.x(at: time, width: size.width) }

            // The baseline, one piece per kept part
            var baseline = Path()
            for segment in viewModel.segments {
                let start = xAt(segment.lowerBound)
                baseline.addRect(CGRect(x: start, y: Self.baselineY - 0.5, width: xAt(segment.upperBound) - start, height: 1))
            }
            context.fill(baseline, with: .color(EditorTheme.ink.opacity(0.12)))

            // A dot per click, on the baseline
            var dots = Path()
            for click in markers.clicks {
                dots.addEllipse(in: CGRect(x: xAt(click) - 1.5, y: Self.baselineY - 1.5, width: 3, height: 3))
            }
            context.fill(dots, with: .color(EditorTheme.ink.opacity(0.75)))

            // A diamond per shortcut, under the baseline
            var squares = Path()
            for key in shortcuts {
                let square = CGRect(x: -3, y: -3, width: 6, height: 6)
                var path = Path(roundedRect: square, cornerRadius: 1.5)
                let center = CGPoint(x: xAt(key.time), y: size.height - 6)
                path = path.applying(CGAffineTransform(rotationAngle: .pi / 4).concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
                squares.addPath(path)
            }
            context.fill(squares, with: .color(EditorTheme.dim.opacity(0.8)))

            // A pill per stretch of typing
            for stretch in typingStretches {
                let start = xAt(stretch.range.lowerBound)
                let end = xAt(stretch.range.upperBound)
                let rect = CGRect(x: start, y: 3, width: end - start, height: size.height - 6)
                guard rect.width > 8 else { continue }
                let pill = Path(roundedRect: rect, cornerRadius: 5)
                context.fill(pill, with: .color(EditorTheme.ink.opacity(0.1)))
                let seconds = (stretch.range.upperBound - stretch.range.lowerBound).formatted(.number.precision(.fractionLength(0...1)))
                let label = context.resolve(
                    Text("Typing · \(seconds) s")
                        .font(.system(size: 9))
                        .foregroundStyle(EditorTheme.dim)
                )
                guard rect.width >= label.measure(in: size).width + 8 else { continue }
                context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height)
        .allowsHitTesting(false)
        .help("Clicks, shortcuts and stretches of typing")
    }

    /// The recorded key presses, empty without telemetry.
    private var keys: [InputTelemetry.Key] {
        guard let telemetry = viewModel.source?.telemetry else { return [] }
        return telemetry.keys
    }

    /// Presses held with ⌘, ⌃ or ⌥: shortcuts, never plain text (which stays private).
    private var shortcuts: [InputTelemetry.Key] {
        keys.filter { key in
            !key.isRepeat && !Set(key.modifiers).isDisjoint(with: ["command", "control", "option"])
        }
    }

    /// The typing stretches, whether or not they've been sped up.
    private var typingStretches: [SpeedRange] {
        TypingStretches.speedUps(for: keys)
    }
}
