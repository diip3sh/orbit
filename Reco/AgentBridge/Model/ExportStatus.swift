//
//  ExportStatus.swift
//  Reco
//

/// How an export started by an agent is going, as `export_recording` reports it.
nonisolated struct ExportStatus: Codable, Equatable, Sendable {
    var status: Status

    /// From 0 to 1.
    var progress: Double

    /// The exported file's path.
    var file: String?
    var error: String?

    nonisolated enum Status: String, Codable, Sendable {
        case exporting
        case done
        case failed
    }
}
