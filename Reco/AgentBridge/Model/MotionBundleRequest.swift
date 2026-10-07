//
//  MotionBundleRequest.swift
//  Reco
//

import Foundation

/// The arguments of `capture_ui` and `preview_motion`: a motion video's bundle.
nonisolated struct MotionBundleRequest: Codable, Equatable, Sendable {

    /// The `.motion` bundle's path, as `edit_motion` returns it.
    var bundle: String

    func validated() throws(AgentToolError) -> URL {
        guard let url = try EditMotionRequest(bundle: bundle, operations: []).existingBundle() else {
            throw .invalidArgument("bundle is missing.")
        }
        return url
    }
}
