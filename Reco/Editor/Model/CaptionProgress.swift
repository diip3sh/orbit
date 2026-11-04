//
//  CaptionProgress.swift
//  Reco
//

import Foundation

/// How far generating captions is.
nonisolated enum CaptionProgress: Equatable, Sendable {

    /// Downloading the language's speech model, from 0 to 1.
    case installing(Double)

    /// Listening to the recording, from 0 to 1.
    case transcribing(Double)

    var fraction: Double {
        switch self {
        case .installing(let fraction), .transcribing(let fraction): fraction
        }
    }

    var title: String {
        switch self {
        case .installing: String(localized: "Downloading the speech model…")
        case .transcribing: String(localized: "Transcribing…")
        }
    }
}
