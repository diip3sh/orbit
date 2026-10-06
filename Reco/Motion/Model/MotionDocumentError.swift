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

    var errorDescription: String? {
        switch self {
        case .invalidCanvas: "The canvas must be at least 16 pixels each way, at 1 to 120 frames a second."
        case .noScenes: "The video has no scenes."
        case .duplicateID(let id): "\"\(id)\" names more than one scene or layer."
        case .invalidDuration(let id): "Scene \"\(id)\" is shorter than a frame."
        case .invalidScale(let id): "Layer \"\(id)\" has a scale that isn't positive."
        case .invalidSize(let id): "Layer \"\(id)\" has a size that isn't positive."
        case .invalidCameraProperty(let id): "Scene \"\(id)\"'s camera animates something other than x, y or z."
        }
    }
}
