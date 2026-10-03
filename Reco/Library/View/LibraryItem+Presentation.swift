//
//  LibraryItem+Presentation.swift
//  Reco
//

import Foundation

/// How the Library's sections and kinds read: their names and symbols.
extension LibrarySection {

    var title: String {
        switch self {
        case .all: "All"
        case .recordings: "Recordings"
        case .webRecordings: "Web Recordings"
        case .exports: "Exports"
        case .screenshots: "Screenshots"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .recordings: "record.circle"
        case .webRecordings: "globe"
        case .exports: "square.and.arrow.up"
        case .screenshots: "camera.viewfinder"
        }
    }

    /// What the section shows when it's empty, and how to fill it.
    var emptyMessage: String {
        switch self {
        case .all: "Recordings and screenshots you make appear here. Use New to start."
        case .recordings: "Screen recordings appear here when you stop them."
        case .webRecordings: "Web recordings appear here once they're rendered."
        case .exports: "Videos you export from the editor appear here."
        case .screenshots: "Screenshots appear here once you save them from their card."
        }
    }
}

extension LibraryItem.Kind {

    var symbol: String {
        switch self {
        case .recording: "record.circle"
        case .webRecording: "globe"
        case .export: "square.and.arrow.up"
        case .screenshot: "camera.viewfinder"
        }
    }
}
