//
//  Recording.swift
//  Reco
//
//  Created by Diip3sh on 28.09.26.
//

import Foundation

/// A recording in the output folder.
nonisolated struct Recording: Identifiable, Hashable, Sendable {
    let url: URL

    /// When it was saved.
    let date: Date

    var id: URL { url }

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }
}
