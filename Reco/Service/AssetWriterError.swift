//
//  AssetWriterError.swift
//  Reco
//

import Foundation

enum AssetWriterError: LocalizedError {
    case failedToCreateWriter
    case writerNotReady
    case failedToStartWriting(Error?)
    case writingFailed(Error?)
    case noOutputURL
    case noFramesWritten

    var errorDescription: String? {
        switch self {
        case .failedToCreateWriter:
            return String(localized: "Failed to create the asset writer.")
        case .writerNotReady:
            return String(localized: "The asset writer is not ready for writing.")
        case .failedToStartWriting(let error):
            return String(localized: "Failed to start writing: \(error?.localizedDescription ?? String(localized: "Unknown error"))")
        case .writingFailed(let error):
            return String(localized: "Writing failed: \(error?.localizedDescription ?? String(localized: "Unknown error"))")
        case .noOutputURL:
            return String(localized: "No output URL was configured.")
        case .noFramesWritten:
            return String(localized: "No video frames were captured. Check screen recording permissions.")
        }
    }
}
