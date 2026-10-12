//
//  StylePreset.swift
//  Reco
//

import Foundation

/// A project's look without its content (spec 0004, S19): the canvas, cursor, clicks, keystrokes and motion, saved
/// under a name as a `.recostyle` file, applied to other recordings and shared as that file. Cuts, speeds, zooms,
/// masks, the crop and the audio mix belong to the recording and stay out.
nonisolated struct StylePreset: Codable, Equatable, Identifiable, Sendable {

    /// Bumped whenever the file layout changes incompatibly.
    static let currentVersion = 1

    static let fileExtension = "recostyle"

    var version = currentVersion
    var name: String
    var canvas: CanvasStyle
    var clickHighlights: ClickHighlightStyle
    var keystrokes: KeystrokeOverlayStyle
    var cursor: CursorStyle
    var zoomMotion: ZoomMotion
    var motionBlur: Double

    /// Names are unique in the store: a style saved under a name takes the place of the one there.
    var id: String { name }

    /// `project`'s look, named `name`.
    init(name: String, of project: EditorProject) {
        self.name = name
        canvas = project.canvas
        clickHighlights = project.clickHighlights
        keystrokes = project.keystrokes
        cursor = project.cursor
        zoomMotion = project.zoomMotion
        motionBlur = project.motionBlur
    }

    /// `project` in this look, its content as it was.
    func applied(to project: EditorProject) -> EditorProject {
        var styled = project
        styled.canvas = canvas
        styled.clickHighlights = clickHighlights
        styled.keystrokes = keystrokes
        styled.cursor = cursor
        styled.zoomMotion = zoomMotion
        styled.motionBlur = motionBlur
        return styled
    }

    /// Whether `project` already looks like this.
    func matches(_ project: EditorProject) -> Bool {
        applied(to: project) == project
    }
}

// MARK: - Decoding

extension StylePreset {

    /// Decodes a file, rejecting any version but ``currentVersion`` with ``UnsupportedVersionError``. Settings added
    /// after version 1 was first written take their defaults when missing, as a project's do.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw UnsupportedVersionError(version: version)
        }
        name = try container.decode(String.self, forKey: .name)
        canvas = try container.decodeIfPresent(CanvasStyle.self, forKey: .canvas) ?? CanvasStyle()
        clickHighlights = try container.decodeIfPresent(ClickHighlightStyle.self, forKey: .clickHighlights) ?? ClickHighlightStyle()
        keystrokes = try container.decodeIfPresent(KeystrokeOverlayStyle.self, forKey: .keystrokes) ?? KeystrokeOverlayStyle()
        cursor = try container.decodeIfPresent(CursorStyle.self, forKey: .cursor) ?? CursorStyle()
        zoomMotion = try container.decodeIfPresent(ZoomMotion.self, forKey: .zoomMotion) ?? .smooth
        motionBlur = try container.decodeIfPresent(Double.self, forKey: .motionBlur) ?? 0
    }
}
