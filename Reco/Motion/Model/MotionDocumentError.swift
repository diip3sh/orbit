//
//  MotionDocumentError.swift
//  Reco
//

import Foundation

/// Why a motion document can't be drawn.
nonisolated enum MotionDocumentError: LocalizedError, Equatable {
    case invalidCanvas
    case noScenes
    case duplicateID(String)
    case invalidDuration(String)
    case invalidScale(String)
    case invalidSize(String)
    case invalidCameraProperty(String)
    case invalidAsset(String)
    case unknownAsset(String)

    /// Asset id and what's wrong with its steps.
    case invalidSteps(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidCanvas: "The canvas must be at least 16 pixels each way, at 1 to 120 frames a second."
        case .noScenes: "The video has no scenes."
        case .duplicateID(let id): "\"\(id)\" names more than one scene or layer."
        case .invalidDuration(let id): "Scene \"\(id)\" is shorter than a frame."
        case .invalidScale(let id): "Layer \"\(id)\" has a scale that isn't positive."
        case .invalidSize(let id): "Layer \"\(id)\" has a size that isn't positive."
        case .invalidCameraProperty(let id): "Scene \"\(id)\"'s camera animates something other than x, y or z."
        case .invalidAsset(let id): "Asset \"\(id)\" needs a web address (http or https) and a viewport of at least 16 pixels each way."
        case .unknownAsset(let id): "Layer \"\(id)\" shows an asset the document doesn't list."
        case .invalidSteps(let id, let reason): "Asset \"\(id)\": \(reason)"
        }
    }
}
