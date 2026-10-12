//
//  ScreenshotFollowUp.swift
//  Reco
//

import Foundation

/// What a screenshot started from a `reco://capture-…?then=` link does in place of opening its card
nonisolated enum ScreenshotFollowUp: String, Sendable {
    case copy
    case save
    case pin

    /// The link's `then` value; nil without one, or with a value this doesn't know
    init?(url: URL) {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "then" })?.value else { return nil }
        self.init(rawValue: value)
    }
}
