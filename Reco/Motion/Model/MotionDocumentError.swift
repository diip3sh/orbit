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
    case invalidSound
    case invalidGradient

    /// Asset id and what's wrong with its steps.
    case invalidSteps(String, String)

    /// Layer or scene id and what's wrong with a move on it.
    case invalidMove(String, String)

    /// Scene id and what's wrong with its shot.
    case invalidShot(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidCanvas: "The canvas must be at least 16 pixels each way, at 1 to 120 frames a second."
        case .noScenes: "The video has no scenes."
        case .duplicateID(let id): "\"\(id)\" names more than one scene or layer."
        case .invalidDuration(let id): "Scene \"\(id)\" is shorter than a frame."
        case .invalidScale(let id): "Layer \"\(id)\" has a scale that isn't positive."
        case .invalidSize(let id): "Layer \"\(id)\" has a size that isn't positive."
        case .invalidCameraProperty(let id):
            "\"\(id)\" animates a property its kind doesn't have: a camera has x, y, z, scale, blur, focus and aperture; a layer no focus or aperture."
        case .invalidAsset(let id): "Asset \"\(id)\" needs a web address (http or https) and a viewport of at least 16 pixels each way."
        case .unknownAsset(let id): "Layer \"\(id)\" shows an asset the document doesn't list."
        case .invalidSound: "The sound's levels must be −24 to 6 dB."
        case .invalidGradient: "The style's gradient needs 2 to 5 colours."
        case .invalidSteps(let id, let reason): "Asset \"\(id)\": \(reason)"
        case .invalidMove(let id, let reason): "A move on \"\(id)\": \(reason)"
        case .invalidShot(let id, let reason): "Scene \"\(id)\"'s shot: \(reason)"
        }
    }
}
