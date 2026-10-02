//
//  EditorProject.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// The edit applied to one recording, saved as `<name>.edit.json` next to it. Deleting the file
/// resets the edit; the recording and its telemetry are never modified.
///
/// All times are seconds on the source video's timeline, the one the telemetry uses.
nonisolated struct EditorProject: Codable, Equatable, Sendable {

    /// Bumped whenever the file layout changes incompatibly.
    static let currentVersion = 1

    var version = currentVersion

    /// Source ranges left out of the output, sorted and non-overlapping. Trimming is a cut at either end.
    var cuts: [Range<Double>] = []

    /// Where the timeline is divided, so the part between two splits can be selected and cut.
    var splits: [Double] = []

    /// Sorted and apart.
    var zooms: [ZoomSegment] = []

    /// How much the camera's moves are blurred, from 0 for none to 1.
    var motionBlur = 0.5

    var clickHighlights = ClickHighlightStyle()
    var keystrokes = KeystrokeOverlayStyle()
    var cursor = CursorStyle()
    var canvas = CanvasStyle()
    var audio = AudioMixSettings()

    /// The project file for a recording: same folder and base name, `.edit.json` extension.
    static func fileURL(for videoURL: URL) -> URL {
        videoURL.deletingPathExtension().appendingPathExtension("edit").appendingPathExtension("json")
    }
}

// MARK: - New projects

extension EditorProject {

    /// The project a recording without one opens with: the styled default with its automatic zooms.
    nonisolated init(opening source: EditorSource) {
        self.init(zooms: source.telemetry.map { AutoZoomGenerator.segments(for: $0, duration: source.duration) } ?? [])
    }
}

// MARK: - Look

extension EditorProject {

    /// This project with `other`'s look: canvas, motion blur, cursor, click highlights and keystrokes, which a
    /// new take of the same page keeps (spec 0008). Cuts, splits, zooms and audio belong to one
    /// recording.
    nonisolated func styled(like other: EditorProject) -> EditorProject {
        var project = self
        project.canvas = other.canvas
        project.motionBlur = other.motionBlur
        project.cursor = other.cursor
        project.clickHighlights = other.clickHighlights
        project.keystrokes = other.keystrokes
        return project
    }
}

// MARK: - Decoding

extension EditorProject {

    /// Decodes a file, rejecting any version but ``currentVersion`` with ``UnsupportedVersionError``.
    /// Settings added after version 1 was first written take their defaults when missing.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw UnsupportedVersionError(version: version)
        }
        cuts = try container.decode([Range<Double>].self, forKey: .cuts)
        splits = try container.decodeIfPresent([Double].self, forKey: .splits) ?? []
        zooms = try container.decodeIfPresent([ZoomSegment].self, forKey: .zooms) ?? []
        motionBlur = try container.decodeIfPresent(Double.self, forKey: .motionBlur) ?? 0.5
        clickHighlights = try container.decodeIfPresent(ClickHighlightStyle.self, forKey: .clickHighlights) ?? ClickHighlightStyle()
        keystrokes = try container.decodeIfPresent(KeystrokeOverlayStyle.self, forKey: .keystrokes) ?? KeystrokeOverlayStyle()
        cursor = try container.decodeIfPresent(CursorStyle.self, forKey: .cursor) ?? CursorStyle()
        canvas = try container.decodeIfPresent(CanvasStyle.self, forKey: .canvas) ?? CanvasStyle()
        audio = try container.decodeIfPresent(AudioMixSettings.self, forKey: .audio) ?? AudioMixSettings()
    }
}
