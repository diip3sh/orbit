//
//  SubtitleFile.swift
//  Reco
//

import Foundation

/// SRT and WebVTT files for a recording's captions, timed on the edited video: cuts and speeds are applied, and
/// a caption entirely cut is left out.
nonisolated enum SubtitleFile {

    /// A caption on the output's timeline, in whole milliseconds.
    struct Entry: Equatable {
        var range: Range<Int>
        var text: String
    }

    /// `cues` on the output's timeline. A caption reaching into a cut ends or starts where the content does.
    static func entries(for cues: [CaptionCue], timeMap: TimeMap) -> [Entry] {
        cues.compactMap { cue in
            let start = milliseconds(timeMap.outputTime(atSource: cue.range.lowerBound))
            let end = milliseconds(timeMap.outputTime(atSource: cue.range.upperBound))
            return start < end ? Entry(range: start..<end, text: cue.text) : nil
        }
    }

    static func srt(for cues: [CaptionCue], timeMap: TimeMap) -> String {
        entries(for: cues, timeMap: timeMap).enumerated().map { index, entry in
            "\(index + 1)\n\(timestamp(entry.range.lowerBound, separator: ",")) --> \(timestamp(entry.range.upperBound, separator: ","))\n\(entry.text)\n"
        }
        .joined(separator: "\n")
    }

    static func vtt(for cues: [CaptionCue], timeMap: TimeMap) -> String {
        let entries = entries(for: cues, timeMap: timeMap).map { entry in
            let text = entry.text.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
            return "\(timestamp(entry.range.lowerBound, separator: ".")) --> \(timestamp(entry.range.upperBound, separator: "."))\n\(text)\n"
        }
        return (["WEBVTT\n"] + entries).joined(separator: "\n")
    }

    /// Writes `movie`'s `.srt` and `.vtt` next to it, replacing any there.
    static func write(_ cues: [CaptionCue], timeMap: TimeMap, beside movie: URL) throws {
        let base = movie.deletingPathExtension()
        try srt(for: cues, timeMap: timeMap).write(to: base.appendingPathExtension("srt"), atomically: true, encoding: .utf8)
        try vtt(for: cues, timeMap: timeMap).write(to: base.appendingPathExtension("vtt"), atomically: true, encoding: .utf8)
    }

    private static func milliseconds(_ seconds: Double) -> Int {
        Int((seconds * 1000).rounded())
    }

    /// `HH:MM:SS` and milliseconds after `separator`: a comma in SRT, a period in VTT.
    private static func timestamp(_ milliseconds: Int, separator: String) -> String {
        let seconds = milliseconds / 1000
        return "\(padded(seconds / 3600, 2)):\(padded(seconds / 60 % 60, 2)):\(padded(seconds % 60, 2))\(separator)\(padded(milliseconds % 1000, 3))"
    }

    private static func padded(_ value: Int, _ length: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(length - digits.count, 0)) + digits
    }
}
