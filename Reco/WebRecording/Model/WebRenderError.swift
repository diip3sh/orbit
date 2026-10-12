//
//  WebRenderError.swift
//  Reco
//

import Foundation

/// Why a web take couldn't be rendered.
nonisolated enum WebRenderError: LocalizedError, Equatable {
    case noURL
    case loadFailed(String)
    case loadTimedOut
    case pageCrashed
    case stalled
    case snapshotFailed
    case writerFailed

    var errorDescription: String? {
        switch self {
        case .noURL: "Enter the address of the page to record."
        case .loadFailed(let reason): "The page couldn't be loaded: \(reason)"
        case .loadTimedOut: "The page took longer than a minute to load."
        case .pageCrashed: "The page crashed."
        case .stalled: "The page stopped drawing frames."
        case .snapshotFailed: "The page couldn't be drawn."
        case .writerFailed: "The movie couldn't be written."
        }
    }
}
