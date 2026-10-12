//
//  LibraryFolders.swift
//  Reco
//

import Foundation

/// The folders the Library lists
nonisolated struct LibraryFolders: Sendable {
    let recordings: URL
    let screenshots: URL

    /// Screenshots nobody saved (spec 0012)
    let history: URL
}
