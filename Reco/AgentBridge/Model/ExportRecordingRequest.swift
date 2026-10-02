//
//  ExportRecordingRequest.swift
//  Reco
//

import Foundation

/// The arguments of the `export_recording` tool: a recording and what to export it as.
nonisolated struct ExportRecordingRequest: Codable, Equatable, Sendable {

    /// The recording's path, as `record_page` reports it.
    var movie: String
    var format: String?

    /// The output's shorter side in pixels.
    var resolution: Int?
    var frameRate: Int?

    private enum CodingKeys: String, CodingKey {
        case frameRate = "frame_rate"
        case movie, format, resolution
    }

    /// The names agents use for the formats.
    static let formats: [String: ExportFormat] = ["hevc": .hevc, "h264": .h264, "prores422": .proRes422, "prores4444": .proRes4444, "gif": .gif]

    /// The recording and the settings asked for. A size or frame rate the recording doesn't offer
    /// is dropped when the export starts.
    func validated() throws(AgentToolError) -> (movie: URL, settings: ExportSettings) {
        guard movie.hasPrefix("/"), FileManager.default.fileExists(atPath: movie) else {
            throw .invalidArgument("movie must be the path of a recording, as record_page returns it.")
        }
        guard let format = Self.formats[format ?? "hevc"] else {
            throw .invalidArgument("format must be one of \(Self.formats.keys.sorted().joined(separator: ", ")).")
        }
        return (URL(filePath: movie), ExportSettings(format: format, resolution: resolution, frameRate: frameRate))
    }
}
