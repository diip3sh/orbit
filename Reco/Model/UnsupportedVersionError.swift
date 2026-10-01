//
//  UnsupportedVersionError.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

import Foundation

/// Thrown when decoding a file whose `version` this build can't read, e.g. one written by a newer
/// Reco. Such files are reported, never guessed at.
nonisolated struct UnsupportedVersionError: LocalizedError, Equatable {
    var version: Int

    var errorDescription: String? {
        "File version \(version) isn't supported by this version of Reco."
    }
}
