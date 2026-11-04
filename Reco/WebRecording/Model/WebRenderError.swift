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
        case .noURL: String(localized: "Enter the address of the page to record.")
        case .loadFailed(let reason): String(localized: "The page couldn't be loaded: \(reason)")
        case .loadTimedOut: String(localized: "The page took longer than a minute to load.")
        case .pageCrashed: String(localized: "The page crashed.")
        case .stalled: String(localized: "The page stopped drawing frames.")
        case .snapshotFailed: String(localized: "The page couldn't be drawn.")
        case .writerFailed: String(localized: "The movie couldn't be written.")
        }
    }
}
